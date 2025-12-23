extends Node
class_name SocialSystem

# Minimal, explainable social simulation:
# - Lazy decay toward faction-based baselines
# - One-hop reputation
# - Gossip with attenuation and bounded memory
# - Cluster detection by mutual trust

const NPC = preload("res://scripts/npc.gd")

const SECONDS_PER_DAY := 86400.0
const DECAY_RATES := { "trust": 0.01, "hate": 0.005, "fear": 0.02 } # per day
const REPUTATION_ATTENUATION := 0.3

@export var seconds_per_day: float = SECONDS_PER_DAY
@export var memory_limit: int = 32
@export var memory_decay_rate: float = 0.05 # per day
@export var gossip_max_hops: int = 2
@export var gossip_process_batch: int = 12
@export var gossip_min_strength: float = 0.01
@export var trust_cluster_threshold: float = 0.6

class RelationEdge:
	var trust: float = 0.0
	var hate: float = 0.0
	var fear: float = 0.0
	var last_ts: float = 0.0

	func _init(now: float = 0.0) -> void:
		last_ts = now


class MemoryItem:
	var type: String
	var about: StringName
	var payload: Dictionary
	var strength: float
	var confidence: float
	var timestamp: float

	func _init(kind: String, about_id: StringName, payload_dict: Dictionary, strength_value: float, confidence_value: float, ts: float) -> void:
		type = kind
		about = about_id
		payload = payload_dict
		strength = clampf(strength_value, -1.0, 1.0)
		confidence = clampf(confidence_value, 0.0, 1.0)
		timestamp = ts


class GossipEvent:
	var source: StringName
	var about: StringName
	var payload: Dictionary
	var confidence: float
	var hops: int
	var timestamp: float

	func _init(source_id: StringName, about_id: StringName, payload_dict: Dictionary, confidence_value: float, hop: int, ts: float) -> void:
		source = source_id
		about = about_id
		payload = payload_dict
		confidence = clampf(confidence_value, 0.0, 1.0)
		hops = hop
		timestamp = ts


class FactionData:
	var id: StringName
	var ideology: Dictionary
	var stance: Dictionary

	func _init(fid: StringName, ideology_dict := {}, stance_dict := {}) -> void:
		id = fid
		ideology = ideology_dict
		stance = stance_dict.duplicate(true)


class ClusterData:
	var id: StringName
	var members: Array[StringName]
	var leader: StringName
	var computed_at: float

	func _init(cid: StringName, member_ids: Array[StringName], leader_id: StringName, ts: float) -> void:
		id = cid
		members = member_ids
		leader = leader_id
		computed_at = ts


var npcs: Dictionary = {} # id -> NPC
var factions: Dictionary = {} # faction_id -> FactionData
var edges: Dictionary = {} # source_id -> { target_id: RelationEdge }
var memories: Dictionary = {} # npc_id -> Array[MemoryItem]
var gossip_queue: Array[GossipEvent] = []
var clusters: Array[ClusterData] = []
var rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()


# --- Registration ----------------------------------------------------------

func register_faction(id: StringName, ideology := {}, stance := {}) -> void:
	var f: FactionData = factions.get(id, FactionData.new(id))
	f.ideology = ideology
	f.stance = stance.duplicate(true)
	factions[id] = f


func set_faction_stance(faction_id: StringName, other_id: StringName, relation_value: float) -> void:
	var f: FactionData = factions.get(faction_id, FactionData.new(faction_id))
	if f.stance == null:
		f.stance = {}
	f.stance[other_id] = clampf(relation_value, -1.0, 1.0)
	factions[faction_id] = f


func register_npc(npc: NPC) -> void:
	if npc == null:
		return
	npcs[npc.id] = npc


# --- Helpers ---------------------------------------------------------------

func _now(ts: float) -> float:
	return ts if ts >= 0.0 else Time.get_unix_time_from_system()


func _edge_map_for(source: StringName) -> Dictionary:
	return edges.get(source, {})


func _ensure_edge(source: StringName, target: StringName, ts: float) -> RelationEdge:
	var src_map: Dictionary = edges.get(source, {})
	var edge: RelationEdge = src_map.get(target)
	if edge == null:
		edge = RelationEdge.new(ts)
		src_map[target] = edge
		edges[source] = src_map
	return edge


func _base_relation_for(source: StringName, target: StringName) -> float:
	var npc_a: NPC = npcs.get(source)
	var npc_b: NPC = npcs.get(target)
	if npc_a == null or npc_b == null:
		return 0.0
	var f: FactionData = factions.get(npc_a.faction_id)
	if f == null:
		return 0.0
	var stance: float = f.stance.get(npc_b.faction_id, 0.0)
	return stance * npc_a.loyalty


func _base_for_metric(metric: String, base_relation: float) -> float:
	match metric:
		"trust":
			return base_relation
		"hate":
			return -base_relation
		"fear":
			return 0.0
		_:
			return base_relation


func _decay_edge(edge: RelationEdge, base_relation: float, ts: float) -> void:
	var delta: float = max(0.0, ts - edge.last_ts)
	if delta <= 0.0:
		return
	var days: float = delta / max(0.001, seconds_per_day)
	for metric in ["trust", "hate", "fear"]:
		var lambda_v: float = DECAY_RATES.get(metric, 0.0)
		var factor: float = exp(-lambda_v * days)
		var base_v: float = _base_for_metric(metric, base_relation)
		var current: float = edge.get(metric)
		current = current * factor + base_v * (1.0 - factor)
		edge.set(metric, clampf(current, -1.0, 1.0))
	edge.last_ts = ts


func _relation_score(source: StringName, target: StringName, ts: float) -> float:
	var trust_v := get_relation_value(source, target, "trust", ts)
	var hate_v := get_relation_value(source, target, "hate", ts)
	return clampf(trust_v - hate_v, -1.0, 1.0)


func _payload_strength(payload: Dictionary) -> float:
	var strength := 0.0
	for v in payload.values():
		strength += abs(float(v))
	return strength


func _scale_payload(payload: Dictionary, scalar: float) -> Dictionary:
	var scaled: Dictionary = {}
	for k in payload.keys():
		scaled[k] = payload[k] * scalar
	return scaled


# --- Relations -------------------------------------------------------------

func get_relation_value(source: StringName, target: StringName, metric: String = "trust", ts: float = -1.0) -> float:
	var now_ts := _now(ts)
	var src_map: Dictionary = edges.get(source)
	if src_map == null:
		return _base_for_metric(metric, _base_relation_for(source, target))
	var edge: RelationEdge = src_map.get(target)
	if edge == null:
		return _base_for_metric(metric, _base_relation_for(source, target))
	_decay_edge(edge, _base_relation_for(source, target), now_ts)
	match metric:
		"trust":
			return edge.trust
		"hate":
			return edge.hate
		"fear":
			return edge.fear
		_:
			return edge.trust


func set_direct_relation(source: StringName, target: StringName, values: Dictionary, ts: float = -1.0) -> void:
	var now_ts := _now(ts)
	var edge := _ensure_edge(source, target, now_ts)
	_decay_edge(edge, _base_relation_for(source, target), now_ts)
	for k in values.keys():
		var v: float = clampf(float(values[k]), -1.0, 1.0)
		match k:
			"trust":
				edge.trust = v
			"hate":
				edge.hate = v
			"fear":
				edge.fear = v
	edge.last_ts = now_ts


func add_relation_delta(source: StringName, target: StringName, delta: Dictionary, ts: float = -1.0) -> void:
	var now_ts := _now(ts)
	var edge := _ensure_edge(source, target, now_ts)
	_decay_edge(edge, _base_relation_for(source, target), now_ts)
	for k in delta.keys():
		var dv: float = float(delta[k])
		match k:
			"trust", "trust_delta":
				edge.trust = clampf(edge.trust + dv, -1.0, 1.0)
			"hate", "hate_delta":
				edge.hate = clampf(edge.hate + dv, -1.0, 1.0)
			"fear", "fear_delta":
				edge.fear = clampf(edge.fear + dv, -1.0, 1.0)
	edge.last_ts = now_ts


func decay_all(ts: float = -1.0) -> void:
	var now_ts := _now(ts)
	for source in edges.keys():
		var src_map: Dictionary = edges[source]
		for target in src_map.keys():
			var edge: RelationEdge = src_map[target]
			_decay_edge(edge, _base_relation_for(source, target), now_ts)


# --- Reputation ------------------------------------------------------------

func resolve_reputation(source: StringName, target: StringName, ts: float = -1.0) -> float:
	var now_ts := _now(ts)
	var score: float = _relation_score(source, target, now_ts)
	var neighbors: Array[StringName] = _edge_map_for(source).keys()
	for n in neighbors:
		if n == target:
			continue
		var trust_ac: float = max(0.0, get_relation_value(source, n, "trust", now_ts))
		if trust_ac <= 0.0:
			continue
		var rel_cb: float = _relation_score(n, target, now_ts)
		score += trust_ac * rel_cb * REPUTATION_ATTENUATION
	return clampf(score, -1.0, 1.0)


# --- Memory ---------------------------------------------------------------

func add_memory(npc_id: StringName, kind: String, about: StringName, payload: Dictionary, confidence: float, ts: float = -1.0) -> void:
	var now_ts := _now(ts)
	var strength: float = _payload_strength(payload)
	var item: MemoryItem = MemoryItem.new(kind, about, payload, strength, confidence, now_ts)
	var arr: Array[MemoryItem] = memories.get(npc_id, []) as Array[MemoryItem]
	arr.append(item)
	if arr.size() > memory_limit:
		arr.pop_front()
	memories[npc_id] = arr


func get_memories(npc_id: StringName, ts: float = -1.0) -> Array[MemoryItem]:
	var now_ts := _now(ts)
	var arr: Array[MemoryItem] = memories.get(npc_id, []) as Array[MemoryItem]
	var result: Array[MemoryItem] = []
	for m: MemoryItem in arr:
		var delta: float = max(0.0, now_ts - m.timestamp)
		var days: float = delta / max(0.001, seconds_per_day)
		var factor: float = exp(-memory_decay_rate * days)
		m.strength *= factor
		m.confidence *= factor
		m.timestamp = now_ts
		if abs(m.strength) >= gossip_min_strength:
			result.append(m)
	memories[npc_id] = result
	return result


# --- Gossip ---------------------------------------------------------------

func enqueue_gossip(source: StringName, about: StringName, payload: Dictionary, confidence: float = 0.6, ts: float = -1.0) -> void:
	var now_ts := _now(ts)
	var ev := GossipEvent.new(source, about, payload, confidence, 0, now_ts)
	gossip_queue.append(ev)


func process_gossip(max_events: int = gossip_process_batch, ts: float = -1.0) -> void:
	var now_ts := _now(ts)
	var processed := 0
	while processed < max_events and gossip_queue.size() > 0:
		var ev: GossipEvent = gossip_queue.pop_front()
		processed += 1
		if ev.hops >= gossip_max_hops:
			continue
		var neighbors: Array[StringName] = _edge_map_for(ev.source).keys()
		for n in neighbors:
			var trust_sn: float = max(0.0, get_relation_value(ev.source, n, "trust", now_ts))
			if trust_sn <= 0.0:
				continue
			if rng.randf() >= trust_sn:
				continue
			var scaled_payload := _scale_payload(ev.payload, trust_sn * ev.confidence)
			if _payload_strength(scaled_payload) < gossip_min_strength:
				continue
			add_relation_delta(n, ev.about, scaled_payload, now_ts)
			add_memory(n, "gossip", ev.about, scaled_payload, ev.confidence, now_ts)
			var next_ev := GossipEvent.new(n, ev.about, scaled_payload, ev.confidence, ev.hops + 1, now_ts)
			gossip_queue.append(next_ev)


# --- Clusters --------------------------------------------------------------

func compute_clusters(ts: float = -1.0) -> Array[ClusterData]:
	var now_ts := _now(ts)
	var visited: Dictionary = {}
	var result: Array[ClusterData] = []
	for npc_id in npcs.keys():
		if visited.has(npc_id):
			continue
		var component: Array[StringName] = []
		var stack: Array[StringName] = [npc_id]
		while stack.size() > 0:
			var cur: StringName = stack.pop_back()
			if visited.has(cur):
				continue
			visited[cur] = true
			component.append(cur)
			for other in _edge_map_for(cur).keys():
				if visited.has(other):
					continue
				var t_ab := get_relation_value(cur, other, "trust", now_ts)
				var t_ba := get_relation_value(other, cur, "trust", now_ts)
				if t_ab >= trust_cluster_threshold and t_ba >= trust_cluster_threshold:
					stack.append(other)
		if component.size() > 1:
			var leader: StringName = _cluster_leader(component, now_ts)
			var cid: StringName = StringName("cluster_%d" % result.size())
			result.append(ClusterData.new(cid, component, leader, now_ts))
	clusters = result
	return result


func _cluster_leader(members: Array[StringName], ts: float) -> StringName:
	var best: StringName = ""
	var best_score: float = -INF
	for m in members:
		var score: float = 0.0
		for other in members:
			if other == m:
				continue
			score += max(0.0, get_relation_value(other, m, "trust", ts))
		if score > best_score:
			best_score = score
			best = m
	return best


# --- Persistence snapshot (lightweight) -----------------------------------

func to_dict() -> Dictionary:
	var faction_payload: Dictionary = {}
	for fid in factions.keys():
		var f: FactionData = factions[fid]
		faction_payload[fid] = {
			"ideology": f.ideology,
			"stance": f.stance,
		}

	var npc_payload: Dictionary = {}
	for nid in npcs.keys():
		var npc: NPC = npcs[nid]
		npc_payload[nid] = {
			"faction_id": npc.faction_id,
			"loyalty": npc.loyalty,
			"title": npc.title,
			"description": npc.description,
		}

	var edge_payload: Array = []
	for source in edges.keys():
		for target in edges[source].keys():
			var e: RelationEdge = edges[source][target]
			edge_payload.append({
				"source": source,
				"target": target,
				"trust": e.trust,
				"hate": e.hate,
				"fear": e.fear,
				"last_ts": e.last_ts,
			})

	var memory_payload: Array = []
	for owner in memories.keys():
		for m: MemoryItem in memories[owner]:
			memory_payload.append({
				"owner": owner,
				"type": m.type,
				"about": m.about,
				"payload": m.payload,
				"strength": m.strength,
				"confidence": m.confidence,
				"timestamp": m.timestamp,
			})

	var cluster_payload: Array = []
	for c: ClusterData in clusters:
		cluster_payload.append({
			"id": c.id,
			"members": c.members,
			"leader": c.leader,
			"computed_at": c.computed_at,
		})

	return {
		"factions": faction_payload,
		"npcs": npc_payload,
		"edges": edge_payload,
		"memories": memory_payload,
		"clusters": cluster_payload,
	}


func load_from_dict(data: Dictionary) -> void:
	factions.clear()
	edges.clear()
	memories.clear()
	clusters.clear()
	gossip_queue.clear()

	if data.has("factions"):
		for fid in data["factions"].keys():
			var fdata: Dictionary = data["factions"][fid]
			register_faction(fid, fdata.get("ideology", {}), fdata.get("stance", {}))

	if data.has("npcs"):
		for nid in data["npcs"].keys():
			var meta: Dictionary = data["npcs"][nid]
			var npc: NPC = NPC.new()
			npc.id = nid
			npc.faction_id = meta.get("faction_id", StringName(""))
			npc.loyalty = meta.get("loyalty", 1.0)
			npc.title = meta.get("title", "")
			npc.description = meta.get("description", "")
			register_npc(npc)

	if data.has("edges"):
		for e in data["edges"]:
			var src: StringName = e.get("source", StringName(""))
			var dst: StringName = e.get("target", StringName(""))
			if src == "" or dst == "":
				continue
			var edge := _ensure_edge(src, dst, e.get("last_ts", _now(-1.0)))
			edge.trust = clampf(e.get("trust", 0.0), -1.0, 1.0)
			edge.hate = clampf(e.get("hate", 0.0), -1.0, 1.0)
			edge.fear = clampf(e.get("fear", 0.0), -1.0, 1.0)
			edge.last_ts = e.get("last_ts", edge.last_ts)

	if data.has("memories"):
		for m in data["memories"]:
			add_memory(
				m.get("owner", StringName("")),
				m.get("type", "gossip"),
				m.get("about", StringName("")),
				m.get("payload", {}),
				m.get("confidence", 1.0),
				m.get("timestamp", _now(-1.0))
			)

	if data.has("clusters"):
		for c in data["clusters"]:
			var members: Array[StringName] = []
			for mid in c.get("members", []):
				members.append(StringName(mid))
			clusters.append(ClusterData.new(
				StringName(c.get("id", "")),
				members,
				StringName(c.get("leader", "")),
				c.get("computed_at", _now(-1.0))
			))


