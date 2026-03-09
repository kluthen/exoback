package bridge

// @spec-link [[module_upsilonapi]]

import (
	"bytes"
	"encoding/json"
	"net/http"

	"github.com/ecumeurs/upsilonbattle/battlearena/controller"
	"github.com/ecumeurs/upsilonbattle/battlearena/ruler/rulermethods"
	"github.com/ecumeurs/upsilontools/tools/actor"
	"github.com/google/uuid"
	"github.com/sirupsen/logrus"
)

type HTTPController struct {
	*controller.Controller
	CallbackURL string
}

func NewHTTPController(id uuid.UUID, callbackURL string) *HTTPController {
	hc := &HTTPController{
		Controller:  controller.NewController(id),
		CallbackURL: callbackURL,
	}

	// Override or add methods to handle Ruler's broadcasts
	hc.AddNotificationHandler(rulermethods.ControllerNextTurn{}, hc.forwardToWebhook, nil)
	hc.AddNotificationHandler(rulermethods.BattleStart{}, hc.forwardToWebhook, nil)
	hc.AddNotificationHandler(rulermethods.BattleEnd{}, hc.forwardToWebhook, nil)
	hc.AddNotificationHandler(rulermethods.EntitiesStateChanged{}, hc.forwardToWebhook, nil)
	hc.AddNotificationHandler(rulermethods.ControllerSkillUsed{}, hc.forwardToWebhook, nil)
	hc.AddNotificationHandler(rulermethods.ControllerAttacked{}, hc.forwardToWebhook, nil)

	return hc
}

func (hc *HTTPController) forwardToWebhook(ctx actor.NotificationContext) {
	logrus.Infof("Forwarding event to webhook: %T", ctx.Msg.TargetMethod)

	payload := map[string]interface{}{
		"event_type": hc.getEventName(ctx.Msg.TargetMethod),
		"data":       ctx.Msg.TargetMethod,
	}

	jsonData, err := json.Marshal(payload)
	if err != nil {
		logrus.Errorf("Failed to marshal webhook payload: %v", err)
		return
	}

	resp, err := http.Post(hc.CallbackURL, "application/json", bytes.NewBuffer(jsonData))
	if err != nil {
		logrus.Errorf("Failed to send webhook: %v", err)
		return
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		logrus.Warnf("Webhook returned non-OK status: %d", resp.StatusCode)
	}
}

func (hc *HTTPController) getEventName(content interface{}) string {
	switch content.(type) {
	case rulermethods.ControllerNextTurn:
		return "turn.started"
	case rulermethods.BattleStart:
		return "game.started"
	case rulermethods.BattleEnd:
		return "game.ended"
	case rulermethods.EntitiesStateChanged:
		return "board.updated"
	case rulermethods.ControllerAttacked:
		return "attacked"
	default:
		return "unknown"
	}
}
