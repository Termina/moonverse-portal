///|
let app_store_key : String = "moonverse-portal"

///|
/// Parse JSON string array like ["a", "b"] into Array[String]
fn parse_string_array(json_str : String) -> Array[String] {
  if json_str.is_empty() || json_str == "[]" {
    return []
  }
  let parsed = try? @json.parse(json_str)
  match parsed {
    Ok(Array(items)) => {
      let result : Array[String] = []
      for item in items {
        match item {
          String(s) => result.push(s)
          _ => ()
        }
      }
      result
    }
    _ => []
  }
}

///|
/// Parse code search details from JSON
fn parse_code_details(json_str : String) -> Array[CodeFileDetail] {
  if json_str.is_empty() || json_str == "[]" {
    return []
  }
  let parsed = try? @json.parse(json_str)
  match parsed {
    Ok(Array(items)) => {
      let result : Array[CodeFileDetail] = []
      for item in items {
        match item {
          Object(obj) => {
            let path = match obj.get("path") {
              Some(String(s)) => s
              _ => ""
            }
            let match_count = match obj.get("matchCount") {
              Some(Number(n, ..)) => n.to_int()
              _ => 0
            }
            let preview = match obj.get("preview") {
              Some(String(s)) => s
              _ => ""
            }
            result.push({ path, match_count, preview })
          }
          _ => ()
        }
      }
      result
    }
    _ => []
  }
}

///|
/// Parse docs search details from JSON
fn parse_docs_details(json_str : String) -> Array[DocFileDetail] {
  if json_str.is_empty() || json_str == "[]" {
    return []
  }
  let parsed = try? @json.parse(json_str)
  match parsed {
    Ok(Array(items)) => {
      let result : Array[DocFileDetail] = []
      for item in items {
        match item {
          Object(obj) => {
            let name = match obj.get("name") {
              Some(String(s)) => s
              _ => ""
            }
            let file_type = match obj.get("type") {
              Some(String(s)) => s
              _ => ""
            }
            let preview = match obj.get("preview") {
              Some(String(s)) => s
              _ => ""
            }
            result.push({ name, file_type, preview })
          }
          _ => ()
        }
      }
      result
    }
    _ => []
  }
}

///|
/// Parse query stats from JSON
fn parse_stats(json_str : String) -> QueryStats {
  if json_str.is_empty() || json_str == "{}" {
    return QueryStats::default()
  }
  let parsed = try? @json.parse(json_str)
  match parsed {
    Ok(Object(obj)) => {
      let llm_calls = match obj.get("llmCalls") {
        Some(Number(n, ..)) => n.to_int()
        _ => 0
      }
      let search_calls = match obj.get("searchCalls") {
        Some(Number(n, ..)) => n.to_int()
        _ => 0
      }
      let tool_calls = match obj.get("toolCalls") {
        Some(Number(n, ..)) => n.to_int()
        _ => 0
      }
      { llm_calls, search_calls, tool_calls }
    }
    _ => QueryStats::default()
  }
}

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
            fn(
              phase,
              message,
              code_count,
              docs_count,
              partial,
              code_details_json,
              docs_details_json,
              stats_json,
            ) {
              let code_search_details = parse_code_details(code_details_json)
              let docs_search_details = parse_docs_details(docs_details_json)
              let stats = parse_stats(stats_json)
              let progress : QueryProgress = {
                phase,
                message,
                code_results_count: code_count,
                docs_results_count: docs_count,
                partial_content: partial,
                code_files: code_search_details.map(fn(d) { d.path }),
                docs_files: docs_search_details.map(fn(d) { d.name }),
                code_search_details,
                docs_search_details,
                stats,
              }
              app.store.val = app.store.val.update(QueryProgress(id, progress))
              @respo.mark_need_rerender()
            },
            fn(
              result,
              code_count,
              docs_count,
              code_details_json,
              docs_details_json,
              stats_json,
            ) {
              let code_search_details = parse_code_details(code_details_json)
              let docs_search_details = parse_docs_details(docs_details_json)
              let stats = parse_stats(stats_json)
              // First update progress to preserve counts and files
              let final_progress : QueryProgress = {
                phase: "complete",
                message: "查询完成",
                code_results_count: code_count,
                docs_results_count: docs_count,
                partial_content: "",
                code_files: code_search_details.map(fn(d) { d.path }),
                docs_files: docs_search_details.map(fn(d) { d.name }),
                code_search_details,
                docs_search_details,
                stats,
              }
              app.store.val = app.store.val.update(
                QueryProgress(id, final_progress),
              )
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
