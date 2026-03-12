package bridge

// @spec-link [[module_upsilonapi]]

import (
	"fmt"
	"log"
	"sync"

	"github.com/ecumeurs/upsilonapi/api"
	"github.com/ecumeurs/upsilonbattle/battlearena"
	"github.com/ecumeurs/upsilonbattle/battlearena/controller/controllers"
	"github.com/ecumeurs/upsilonbattle/battlearena/entity"
	"github.com/ecumeurs/upsilonbattle/battlearena/entity/entitygenerator"
	"github.com/ecumeurs/upsilonbattle/battlearena/ruler"
	"github.com/ecumeurs/upsilonbattle/battlearena/ruler/rulermethods"
	"github.com/ecumeurs/upsilonbattle/battlearena/ruler/turner"
	"github.com/ecumeurs/upsilonmapdata/grid"
	"github.com/ecumeurs/upsilonmapdata/grid/position"
	"github.com/ecumeurs/upsilonmapmaker/gridgenerator"
	"github.com/ecumeurs/upsilontools/tools/messagequeue/message"
	"github.com/google/uuid"
)

type ArenaBridge struct {
	mu     sync.RWMutex
	arenas map[uuid.UUID]*battlearena.BattleArena
}

var bridge = &ArenaBridge{
	arenas: make(map[uuid.UUID]*battlearena.BattleArena),
}

func Get() *ArenaBridge {
	return bridge
}

func (b *ArenaBridge) StartArena(start api.ArenaStartRequest) (uuid.UUID, *grid.Grid, []entity.Entity, turner.TurnState, error) {
	matchID := uuid.MustParse(start.MatchID)
	battleArena := battlearena.NewBattleArena(matchID)
	battleArena.Metadata["CallbackURL"] = start.CallbackURL

	// Ensure Ruler ID matches MatchID as per caller expectations
	battleArena.Ruler.ID = matchID

	b.mu.Lock()
	b.arenas[matchID] = battleArena
	b.mu.Unlock()

	// this bypass actor's owning resource, we should probably use the SetGrid message instead (doesn't exist yet).
	battleArena.Ruler.SetGrid(gridgenerator.GeneratePlainSquare(10, 10))
	battleArena.Ruler.SetNbControllers(len(start.Players))

	// We need to wait for the reply to get the initial state
	respChan := make(chan *message.Message)
	defer close(respChan)

	count := len(start.Players)

	for _, p := range start.Players {

		for _, ee := range p.Entities {
			e := entitygenerator.GenerateRandomEntity()
			e.Type = entity.Character
			e.Name = ee.Name
			e.ID = uuid.MustParse(ee.ID)
			e.ControllerID = uuid.MustParse(p.ID)

			e.RepsertPropertyCMaxValue("HP", ee.MaxHP)
			e.RepsertPropertyValue("HP", ee.MaxHP)
			e.RepsertPropertyCMaxValue("Movement", ee.Move)
			e.RepsertPropertyValue("Movement", ee.Move)
			e.RepsertPropertyValue("Attack", ee.Attack)
			e.RepsertPropertyValue("Defense", ee.Defense)

			// this bypass actor's owning resource, we should probably use the AddEntity message instead (doesn't exist yet).
			battleArena.Ruler.AddEntity(e)
		}

		if p.IA {
			ctrl := controllers.NewAggressiveController(uuid.MustParse(p.ID), fmt.Sprintf("AggressiveController-%s", p.ID))
			ctrl.Start()

			msg := message.Create(ctrl, rulermethods.AddController{
				Controller:   ctrl,
				ControllerID: ctrl.ID,
			}, nil)

			battleArena.Ruler.SendActor(msg, respChan)

		} else {

			// We need at least one controller to get the initial state
			// In the future, we might add multiple based on players payload
			hc := NewHTTPController(uuid.MustParse(p.ID), start.CallbackURL)
			hc.Start()

			msg := message.Create(hc, rulermethods.AddController{
				Controller:   hc,
				ControllerID: hc.ID,
			}, nil)

			battleArena.Ruler.SendActor(msg, respChan)
		}
	}

	for ; count > 0; count-- {
		log.Printf("Waiting ... (%d)", count)
		<-respChan
	}

	res := make([]entity.Entity, 0, 6)
	for _, v := range battleArena.Ruler.GameState.Entities {
		res = append(res, v)
	}

	// this is bad, because we access data directly, bypassing the actor... we should probably poll for appropriate data so that we're sure to have readonly copies.
	return matchID,
		battleArena.Ruler.GameState.Grid,
		res,
		battleArena.Ruler.GameState.Turner.GetTurnState(),
		nil
}

func (b *ArenaBridge) ArenaAction(arenaID uuid.UUID, req api.ArenaActionMessage) (bool, string, interface{}) {
	r, ok := b.GetArena(arenaID)
	if !ok {
		return false, "arena not found", nil
	}

	respChan := make(chan *message.Message)
	defer close(respChan)
	// Translate HTTP action to Ruler message
	// This is a simplified mapping; more logic needed for full support
	switch req.Data.Type {
	case "attack":
		r.SendActor(message.Create(nil, rulermethods.ControllerAttack{
			ControllerID: uuid.MustParse(req.Data.PlayerID),
			EntityID:     uuid.MustParse(req.Data.EntityID),
			Target:       position.New(req.Data.TargetCoords[0].X, req.Data.TargetCoords[0].Y, 1),
		}, nil), respChan)
	case "pass":
		r.SendActor(message.Create(nil, rulermethods.EndOfTurn{
			ControllerID: uuid.MustParse(req.Data.PlayerID),
			EntityID:     uuid.MustParse(req.Data.EntityID),
		}, nil), respChan)
	case "move":
		path := make([]position.Position, len(req.Data.TargetCoords))
		for i, c := range req.Data.TargetCoords {
			path[i] = position.New(c.X, c.Y, 1)
		}
		r.SendActor(message.Create(nil, rulermethods.ControllerMove{
			ControllerID: uuid.MustParse(req.Data.PlayerID),
			EntityID:     uuid.MustParse(req.Data.EntityID),
			Path:         path,
		}, nil), respChan)
	default:
		// Just notify the ruler for now with a generic message if type matches?
		// Better to implement specific methods

		r.SendActor(message.Create(nil, rulermethods.EndOfTurn{
			ControllerID: uuid.MustParse(req.Data.PlayerID),
			EntityID:     uuid.MustParse(req.Data.EntityID),
		}, nil), respChan)
	}

	// Wait for the reply
	res := <-respChan

	if res.HasError {
		return false, res.ErrorMessage, nil
	}

	return true, fmt.Sprintf("action %s accepted", req.Data.Type), res.Content
}

func (b *ArenaBridge) GetArena(id uuid.UUID) (*ruler.Ruler, bool) {
	b.mu.RLock()
	defer b.mu.RUnlock()
	r, ok := b.arenas[id]
	if !ok {
		return nil, false
	}
	return r.Ruler, ok
}
