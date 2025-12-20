///|
let app_store_key : String = "moonverse-portal"

///|
fn view(
  store : Store,
) -> @respo_node.RespoNode[ActionOp] raise @respo_node.RespoCommonError {
  if false {
    raise @respo_node.RespoCommonError("guarded")
  }
  // @dom_ffi.log("Store to render: " + store.to_json().stringify(indent=2))
  comp_app(store.states.pick("app"), store)
}

///|
fn main {
  let window = @dom_ffi.window()
  if window.document().query_selector(".app") is Some(mount_target) {
    let mount_target = mount_target.reinterpret_as_node()
    let mut store_0 : Store = @respo.try_load_storage(app_store_key)
    store_0 = { ..store_0, states: @respo.RespoStatesTree::default() }
    let app : @respo.RespoApp[Store] = {
      store: Ref::new(store_0),
      mount_target,
      storage_key: app_store_key,
    }
    app.backup_model_beforeunload()
    // @dom_ffi.log("store: " + app.store.val.to_json().stringify(indent=2))
    app.render_loop(fn() { view(app.store.val) }, fn(op) {
      if not(op is StatesChange(_)) {
        @dom_ffi.log("Action: \{op}")
      }
      app.store.val = app.store.val.update(op)
      match op {
        StartQuery(prompt) => {
          // Get the id that was just created
          let id = app.store.val.next_id - 1
          run_query_js(
            prompt,
            fn(result) {
              app.store.val = app.store.val.update(QuerySuccess(id, result))
              @respo.mark_need_rerender()
            },
            fn(err) {
              app.store.val = app.store.val.update(QueryError(id, err))
              @respo.mark_need_rerender()
            },
          )
        }
        _ => ()
      }
    })
    let dev_mode = @dom_ffi.new_url_search_params(window.location().search()).get(
      "mode",
    )
    @dom_ffi.log("dev mode: \{dev_mode}")
  } else {
    @dom_ffi.log("No mount target found")
  }
}
