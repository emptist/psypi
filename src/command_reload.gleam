import gleam/javascript/promise
import pi_extension.{ctx_reload, notify_info}

pub fn on_autonomic_reload(ctx: a) -> promise.Promise(Result(String, String)) {
  notify_info(ctx, "Reloading extensions...")
  promise.map(ctx_reload(ctx), fn(_) {
    notify_info(ctx, "Extensions reloaded. Monitor updated.")
    Ok("Extensions reloaded.")
  })
}
