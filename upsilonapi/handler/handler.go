package handler

import (
	"net/http"
	"time"

	"github.com/ecumeurs/upsilonapi/api"
	"github.com/ecumeurs/upsilonapi/bridge"
	"github.com/ecumeurs/upsilonapi/stdmessage"
	"github.com/ecumeurs/upsilonbattle/battlearena/ruler/rulermethods"
	"github.com/ecumeurs/upsilonmapdata/grid/cell"
	"github.com/ecumeurs/upsilonmapdata/grid/position"
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

// @spec-link [[api_go_battle_engine]]

// HandleArenaStart handles the start of a new arena; initializes a new ruler and returns the initial state.
func HandleArenaStart(c *gin.Context) {
	var req api.ArenaStartMessage

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, api.NewError("", err.Error()))
		return
	}

	id, g, entities, turner, err := bridge.Get().StartArena(req.Data)
	if err != nil {
		c.JSON(http.StatusInternalServerError, api.NewError(req.RequestID, err.Error()))
		return
	}

	bs := api.BoardState{
		StartTime:       time.Now(),
		Timeout:         time.Now().Add(30 * time.Second),
		CurrentEntityID: turner.CurrentEntityTurn.String(),
	}

	// Map Grid - assuming 2D for now as per api.Grid comment
	bs.Grid = api.Grid{
		Width:  g.Width,
		Height: g.Length,
		Cells:  make([][]api.Cell, g.Width),
	}
	for x := 0; x < g.Width; x++ {
		bs.Grid.Cells[x] = make([]api.Cell, g.Length)
		for y := 0; y < g.Length; y++ {
			z := g.TopMostCellAt(x, y)
			cl, ok := g.CellAt(position.New(x, y, z))
			if ok {
				bs.Grid.Cells[x][y] = api.Cell{
					EntityID: cl.EntityID.String(),
					Obstacle: cl.Type == cell.Obstacle,
				}
				if cl.EntityID == uuid.Nil {
					bs.Grid.Cells[x][y].EntityID = ""
				}
			}
		}
	}

	entityToPlayer := make(map[uuid.UUID]string)
	for _, e := range entities {
		entityToPlayer[e.ID] = e.ControllerID.String()

		bs.Entities = append(bs.Entities, api.NewEntity(e))

		if e.ID == turner.CurrentEntityTurn {
			bs.CurrentPlayerID = e.ControllerID.String()
		}
	}

	for _, t := range turner.RemainingTurns {
		bs.Turn = append(bs.Turn, api.Turn{
			EntityID: t.EntityId.String(),
			PlayerID: entityToPlayer[t.EntityId],
			Delay:    t.Delay,
		})
	}

	c.JSON(http.StatusOK, api.NewSuccess(req.RequestID, "Arena started", api.ArenaStartResponse{
		ArenaID:      id.String(),
		InitialState: bs,
	}))
}

// HandleArenaAction handles an action in an arena; sends the action to the ruler.
func HandleArenaAction(c *gin.Context) {
	// extract StandardMessage first .

	var req api.ArenaActionMessage
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, api.NewError("", err.Error()))
		return
	}
	idStr := c.Param("id")
	arenaID, err := uuid.Parse(idStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, api.NewError(req.RequestID, "invalid arena id"))
		return
	}

	ok, msg, data := bridge.Get().ArenaAction(arenaID, req)
	if !ok {
		c.JSON(http.StatusBadRequest, api.NewError(req.RequestID, msg))
		return
	}

	var res interface{}

	switch d := data.(type) {
	case rulermethods.ControllerAttackReply:
		res = api.NewEntity(d.Entity)

	case rulermethods.ControllerMoveReply:
		res = api.NewEntity(d.Entity)

	default:
		// end of turn
		res = stdmessage.DataNil{}
	}

	c.JSON(http.StatusOK, api.NewSuccess(req.RequestID, msg, res))
}
