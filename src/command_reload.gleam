import gleam/javascript/promise
import pi_extension.{ctx_notify, ctx_reload}

pub fn on_autonomic_reload(ctx: a) -> promise.Promise(Result(String, String)) {
  ctx_notify(ctx, "Reloading extensions...", "info")
  promise.map(ctx_reload(ctx), fn(_) {
    ctx_notify(ctx, "Extensions reloaded. Monitor updated.", "info")
    Ok("Extensions reloaded.")
  })
}
