package main

import (
	"bytes"
	"encoding/json"
	"log"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/ecumeurs/upsilonapi/api"
	"github.com/ecumeurs/upsilonapi/handler"
	"github.com/ecumeurs/upsilonapi/stdmessage"
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
)

func setupRouter() *gin.Engine {
	gin.SetMode(gin.TestMode)
	r := gin.Default()
	internal := r.Group("/internal")
	{
		internal.POST("/arena/start", handler.HandleArenaStart)
		internal.POST("/arena/:id/action", handler.HandleArenaAction)
	}
	return r
}

func TestArenaStartEndpoint(t *testing.T) {
	router := setupRouter()
	id := uuid.New().String()
	mid := uuid.New().String()
	w := httptest.NewRecorder()
	players := []api.Player{
		api.Player{
			ID:   uuid.NewString(),
			Team: 1,
			Entities: []api.Entity{
				api.Entity{
					ID:       uuid.NewString(),
					PlayerID: "",
					Name:     "P1E1",
					HP:       10,
					Attack:   3,
					Defense:  1,
					MaxHP:    10,
					Move:     2,
					MaxMove:  2,
					Position: api.Position{
						X: 0,
						Y: 5}}},
			IA: true,
		},
		api.Player{
			ID:   uuid.NewString(),
			Team: 2,
			Entities: []api.Entity{
				api.Entity{
					ID:       uuid.NewString(),
					PlayerID: "",
					Name:     "P2E1",
					HP:       10,
					Attack:   3,
					Defense:  1,
					MaxHP:    10,
					Move:     2,
					MaxMove:  2,
					Position: api.Position{
						X: 5,
						Y: 0}}},
			IA: true}}

	reqBody, _ := json.Marshal(api.ArenaStartMessage{
		RequestID: id,
		Message:   "Start",
		Success:   true,
		Data: api.ArenaStartRequest{
			MatchID:     mid,
			CallbackURL: "http://localhost:9999/webhook",
			Players:     players,
		},
		Meta: stdmessage.MetaNil{},
	})
	req, _ := http.NewRequest("POST", "/internal/arena/start", bytes.NewBuffer(reqBody))
	req.Header.Set("Content-Type", "application/json")
	router.ServeHTTP(w, req)

	assert.Equal(t, http.StatusOK, w.Code)

	var resp api.ArenaStartResponseMessage
	err := json.Unmarshal(w.Body.Bytes(), &resp)
	log.Printf("Json Response: %s", w.Body.Bytes())

	assert.NoError(t, err)
	assert.Equal(t, resp.RequestID, id)
	assert.Equal(t, resp.Success, true)
	assert.NotEmpty(t, resp.Data.ArenaID)
	assert.NotEmpty(t, resp.Data.InitialState)
}
