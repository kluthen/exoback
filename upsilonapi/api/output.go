package api

import (
	"time"

	"github.com/ecumeurs/upsilonapi/stdmessage"
	"github.com/ecumeurs/upsilonbattle/battlearena/entity"
)

// @spec-link [[api_go_battle_engine]]

type ArenaActionResponse struct {
	Status string `json:"status"`
}

type ArenaStartResponse struct {
	ArenaID      string `json:"arena_id"`
	InitialState any    `json:"initial_state"`
}

// @spec-link [[entity_grid]]

type Cell struct {
	EntityID string `json:"entity_id"` // if any
	Obstacle bool   `json:"obstacle"`  // if any
}

// Grid: A 2D array of cells; for our purpose as in this implementation, the height will be fixed at 1 for every cell giving us a flat map.
type Grid struct {
	Width  int      `json:"width"`
	Height int      `json:"height"`
	Cells  [][]Cell `json:"cells"` // Cells are stored in width-major order.
}

type Turn struct {
	PlayerID string `json:"player_id"`
	Delay    int    `json:"delay"`
	EntityID string `json:"entity_id"`
}

type BoardState struct {
	Entities        []Entity  `json:"entities"`
	Grid            Grid      `json:"grid"`
	Turn            []Turn    `json:"turn"`
	CurrentPlayerID string    `json:"current_player_id"`
	CurrentEntityID string    `json:"current_entity_id"`
	Timeout         time.Time `json:"timeout"` // End of turn date.
	StartTime       time.Time `json:"start_time"`
	WinnerID        string    `json:"winner_id"` // if any, the game is done; based on player id.
}

// ArenaEvent is the payload for the webhook
type ArenaEvent struct {
	MatchID   string     `json:"match_id"`   // targeted match
	EventType string     `json:"event_type"` // Board State Change, Turn Started, Battle Start, Battle End
	PlayerID  string     `json:"player_id"`  // if set, targeted player
	EntityID  string     `json:"entity_id"`  // if set, targeted entity
	Data      BoardState `json:"data"`       // event specific data (board change)
	Timeout   time.Time  `json:"timeout"`    // End of turn date.
}

type ArenaActionResponseMessage = stdmessage.StandardMessage[ArenaActionResponse, stdmessage.MetaNil]
type ArenaStartResponseMessage = stdmessage.StandardMessage[ArenaStartResponse, stdmessage.MetaNil]
type ArenaEventMessage = stdmessage.StandardMessage[ArenaEvent, stdmessage.MetaNil]

// NewError creates a new StandardMessage with the given error.
func NewError(requestId string, err string) stdmessage.StandardMessage[stdmessage.DataNil, stdmessage.MetaNil] {
	return stdmessage.StandardMessage[stdmessage.DataNil, stdmessage.MetaNil]{
		RequestID: requestId,
		Message:   err,
		Meta:      stdmessage.MetaNil{},
		Success:   false,
		Data:      stdmessage.DataNil{},
	}
}

// NewSuccess creates a new StandardMessage with the given data.
func NewSuccess[T any](requestId string, msg string, data T) stdmessage.StandardMessage[T, stdmessage.MetaNil] {
	return stdmessage.StandardMessage[T, stdmessage.MetaNil]{
		RequestID: requestId,
		Message:   msg,
		Meta:      stdmessage.MetaNil{},
		Success:   true,
		Data:      data,
	}
}

// NewEntity creates a new Entity from the given entity (upsilonbattle's)
func NewEntity(entity entity.Entity) Entity {
	return Entity{
		ID:       entity.ID.String(),
		PlayerID: entity.ControllerID.String(),
		Name:     entity.Name,
		HP:       entity.GetPropertyC("HP").GetValue(),
		MaxHP:    entity.GetPropertyC("HP").GetMaxValue(),
		Attack:   entity.GetPropertyI("Attack").I(),
		Defense:  entity.GetPropertyI("Defense").I(),
		Move:     entity.GetPropertyC("Movement").GetValue(),
		MaxMove:  entity.GetPropertyC("Movement").GetMaxValue(),
		Position: Position{X: entity.Position.X, Y: entity.Position.Y},
	}
}
