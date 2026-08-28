# Issue: Modernize Actor Library with Go Generics (Templates)

**ID:** `20260418_actor_generics_modernization`
**Ref:** `ISS-049`
**Date:** 2026-04-18
**Severity:** Low
**Status:** Open
**Component:** `upsilontools/tools/actor`
**Affects:** Entire `upsilonbattle` and `upsilonapi` service communications

---

## Summary

The current Actor implementation was designed before Go 1.18 (Generics). It relies heavily on `interface{}`, reflection, and runtime type assertions. This pattern is verbose, error-prone, and lacks compile-time safety. Migrating to a Generic-based (Template) system would significantly simplify the code and harden the stability of the entire message-passing architecture.

---

## Technical Description

### Background
The Actor library uses a dispatch loop that routes messages based on the `reflect.TypeOf` the incoming message's `TargetMethod`. This allows for a flexible "message-as-a-method" pattern.

### The Current Strategy
Currently, every actor handler follows this pattern:
1. Register a handler with an empty struct instance for type discovery.
2. In the handler function, receive a non-generic `NotificationContext`.
3. **Manually type-assert** the message payload to the expected struct.

Example:
```go
// Registration
ctrl.AddCallHandler(controllermethods.SetQueue{}, ctrl.setQueue, nil)

// Handler
func (c *Controller) setQueue(ctx actor.CallContext) {
    // RUNTIME RISK: If TargetMethod is not SetQueue, this panics or fails.
    method := ctx.Msg.TargetMethod.(controllermethods.SetQueue)
    c.Ruler = method.Ruler
}
```

### The Proposed Modernization
By using Go Generics, we can move the type-safety from runtime to compile-time.

1. **Typed Contexts**: `TypedNotificationContext[T any]` which contains the payload already cast to `T`.
2. **Typed Registration**: `AddNotificationHandlerT[T any](act *Actor, handler func(TypedNotificationContext[T]))`.
3. **Ergonomic Dispatch**: `Notify[T](target, data T)` instead of manual `message.Create`.

Proposed pattern:
```go
// Registration (Type-safe)
actor.AddNotificationHandlerT(act, ctrl.setQueue)

// Handler (Type-safe)
func (c *Controller) setQueue(ctx actor.TypedNotificationContext[controllermethods.SetQueue]) {
    // Data is already typed!
    c.Ruler = ctx.Data.Ruler
}
```

### Where This Pattern Exists Today
- [actor.go](file:///home/bastien/work/upsilon/projbackend/upsilontools/tools/actor/actor.go)
- [controller.go](file:///home/bastien/work/upsilon/projbackend/upsilonbattle/battlearena/controller/controller.go)
- [ruler.go](file:///home/bastien/work/upsilon/projbackend/upsilonbattle/battlearena/ruler/ruler.go)

---

## Risk Assessment

| Factor | Value |
|---|---|
| Likelihood | N/A (Feature Request) |
| Impact if triggered | High (If migration is done poorly, it breaks all inter-service comms) |
| Detectability | High (Compiler errors will catch most issues) |
| Current mitigant | Extensive manual testing and log-based debugging |

---

## Recommended Fix

**Short term:** File this issue to track technical debt and architectural opportunity.  
**Medium term:** Implement a parallel "Typed" API in `upsilontools/tools/actor` and migrate non-critical utility actors.  
**Long term:** Perform a full sweep of the codebase to migrate `upsilonbattle` and `upsilonapi` to the typed system, eventually deprecating the reflection-based handlers.

---

## References

- [actor.go](file:///home/bastien/work/upsilon/projbackend/upsilontools/tools/actor/actor.go)
- [message.go](file:///home/bastien/work/upsilon/projbackend/upsilontools/tools/messagequeue/message/message.go)
- Go Generics Documentation: https://go.dev/doc/tutorial/generics
