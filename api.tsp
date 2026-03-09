import "@typespec/http";
import "@typespec/rest";

using TypeSpec.Http;
using TypeSpec.Rest;

@service({
  title: "Upsilon API",
  version: "1.0.0",
})
@server("http://localhost:8080", "Local development server")
namespace UpsilonAPI;

/**
 * Standard envelope for all API messages.
 */
model StandardMessage<T, M = {}> {
  request_id: string;
  message: string;
  success: boolean;
  data: T;
  meta: M;
}

model Position {
  x: int32;
  y: int32;
}

/**
 * Represents a character entity in the battle.
 */
model Entity {
  id: string;
  player_id: string;
  name: string;
  hp: int32;
  max_hp: int32;
  attack: int32;
  defense: int32;
  move: int32;
  max_move: int32;
  position: Position;
}

model Player {
  id: string;
  entities: Entity[];
  team: int32;
  ia: boolean;
}

model ArenaStartRequest {
  match_id: string;
  callback_url: string;
  players: Player[];
}

model ArenaStartResponse {
  arena_id: string;
  initial_state: BoardState;
}

model Cell {
  entity_id: string;
  obstacle: boolean;
}

model Grid {
  width: int32;
  height: int32;
  cells: Cell[][];
}

model Turn {
  player_id: string;
  delay: int32;
  entity_id: string;
}

model BoardState {
  entities: Entity[];
  grid: Grid;
  turn: Turn[];
  current_player_id: string;
  current_entity_id: string;
  timeout: utcDateTime;
  start_time: utcDateTime;
  winner_id: string;
}

model ArenaActionRequest {
  player_id: string;
  type: string;
  target_coords: Position[];
  entity_id: string;
}

model ArenaActionResponse {
  status: string;
}

/**
 * Webhook event sent to the callback URL.
 */
model ArenaEvent {
  match_id: string;
  event_type: "Board State Change" | "Turn Started" | "Battle Start" | "Battle End";
  player_id: string;
  entity_id: string;
  data: BoardState;
  timeout: utcDateTime;
}

@route("/internal")
namespace Internal {
  @route("/arena/start")
  @post
  op startArena(@body body: StandardMessage<ArenaStartRequest>): StandardMessage<ArenaStartResponse>;

  @route("/arena/{id}/action")
  @post
  @doc("Performs an action in the specified arena.")
  op takeAction(
    @path id: string,
    @body body: StandardMessage<ArenaActionRequest>
  ): StandardMessage<ArenaActionResponse | Entity | {}>;
}

/**
 * Webhooks are dispatched to the callback_url provided in startArena.
 */
@route("/")
namespace Webhooks {
  @post
  @doc("Receives asynchronous updates from the battle engine.")
  op receiveEvent(@body body: StandardMessage<ArenaEvent>): void;
}
