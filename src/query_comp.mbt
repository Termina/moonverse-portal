///|
struct QueryState {
  input_val : String
  loading : Bool
} derive(Default, ToJson, @json.FromJson)

///|
fn comp_query(
  states : @respo.RespoStatesTree,
  result : String,
  error : String,
) -> @respo_node.RespoNode[ActionOp] {
  let cursor = states.path()
  let state = (states.cast_branch() : QueryState)

  ///|
  fn start_query_request(
    prompt : String,
    dispatch : @respo_node.DispatchFn[ActionOp],
  ) -> Unit {
    println("start_query_request: prompt = \{prompt}")
    // 设置 loading = true
    dispatch.set_state(cursor, QueryState::{ input_val: prompt, loading: true }) catch {
      _ => ()
    }
    let _ = @js_async.Promise::from_async(async fn() {
      println("Inside async: starting POST /query")
      // POST /query
      let body = "{\"prompt\": \"" + prompt + "\", \"mode\": \"hybrid\"}"
      println("Request body: \{body}")
      let resp = fetch("http://localhost:8080/query", make_post_options(body)).wait() catch {
        error => {
          println("Fetch error: \{error}")
          dispatch.set_state(cursor, QueryState::{
            input_val: prompt,
            loading: false,
          })
          dispatch.run(QueryError("Fetch failed: " + error.to_string()))
          return
        }
      }
      println("Response status: \{resp.status()}, ok: \{resp.ok()}")
      if not(resp.ok()) {
        dispatch.set_state(cursor, QueryState::{
          input_val: prompt,
          loading: false,
        })
        dispatch.run(
          QueryError("Failed to start query: " + resp.status().to_string()),
        )
        return
      }
      let json_resp = resp.json().wait() catch {
          error => {
            println("JSON parse error: \{error}")
            dispatch.set_state(cursor, QueryState::{
              input_val: prompt,
              loading: false,
            })
            dispatch.run(QueryError("JSON parse failed: " + error.to_string()))
            return
          }
        }
      let id = get_id(json_resp)
      println("Got task id: \{id}")

      // 轮询 /query/{id}
      while true {
        println("Polling /query/\{id}")
        let poll_resp = fetch(
          "http://localhost:8080/query/" + id,
          make_get_options(),
        ).wait() catch {
          error => {
            println("Poll fetch error: \{error}")
            dispatch.set_state(cursor, QueryState::{
              input_val: prompt,
              loading: false,
            })
            dispatch.run(QueryError("Poll fetch failed: " + error.to_string()))
            return
          }
        }
        if not(poll_resp.ok()) {
          dispatch.set_state(cursor, QueryState::{
            input_val: prompt,
            loading: false,
          })
          dispatch.run(
            QueryError(
              "Failed to poll query: " + poll_resp.status().to_string(),
            ),
          )
          return
        }
        let poll_json = poll_resp.json().wait() catch {
            error => {
              println("Poll JSON parse error: \{error}")
              dispatch.set_state(cursor, QueryState::{
                input_val: prompt,
                loading: false,
              })
              dispatch.run(
                QueryError("Poll JSON parse failed: " + error.to_string()),
              )
              return
            }
          }
        let status = get_status(poll_json)
        println("Poll status: \{status}")
        if status == "done" {
          let result = get_result(poll_json)
          println("Query done, result length: \{result.length()}")
          dispatch.set_state(cursor, QueryState::{
            input_val: prompt,
            loading: false,
          })
          dispatch.run(QuerySuccess(result))
          break
        } else if status == "error" {
          println("Query failed on server")
          dispatch.set_state(cursor, QueryState::{
            input_val: prompt,
            loading: false,
          })
          dispatch.run(QueryError("Query failed on server"))
          break
        }
        sleep(1000).wait() catch {
          _ => ()
        }
      }
    })
    println("start_query_request: after async")
  }

  @respo_node.div(class_name=style_query_container, [
    // 标题
    @respo_node.div(class_name=style_title, [
      @respo_node.text_node("MoonBit Query"),
    ]),
    // 输入区域
    @respo_node.div(class_name=style_input_row, [
      @respo_node.input(
        value=state.input_val,
        placeholder="Enter your question about MoonBit...",
        class_name=style_input,
        on_input=fn(e, dispatch) {
          match e {
            Input(value~, ..) =>
              dispatch.set_state(cursor, { ..state, input_val: value })
            _ => ()
          }
        },
      ),
      @respo_node.button(
        inner_text=if state.loading { "Loading..." } else { "Submit" },
        class_name=style_button,
        on_click=fn(_e, dispatch) {
          if not(state.loading) && not(state.input_val.is_empty()) {
            let prompt = state.input_val
            println("Submit clicked, prompt: \{prompt}")
            dispatch.run(StartQuery(prompt))
            start_query_request(prompt, dispatch)
          }
        },
      ),
    ]),
    // 错误信息
    if not(error.is_empty()) {
      @respo_node.div(class_name=style_error, [@respo_node.text_node(error)])
    } else {
      @respo_node.span([])
    },
    // 结果显示
    if not(result.is_empty()) {
      @respo_node.div(class_name=style_result, [@respo_node.text_node(result)])
    } else if state.loading {
      @respo_node.div(class_name=style_loading, [
        @respo_node.text_node("Thinking..."),
      ])
    } else {
      @respo_node.span([])
    },
  ])
}

// Static styles

///|
let style_query_container : String = @respo_node.static_style([
  (
    "&",
    @css.respo_style(
      padding=Px(20),
      max_width=Px(800),
      margin=Auto,
      font_family="system-ui, -apple-system, sans-serif",
    ),
  ),
])

///|
let style_title : String = @respo_node.static_style([
  (
    "&",
    @css.respo_style(
      font_size=24,
      font_weight="bold",
      margin_bottom=Px(16),
      color=Hsl(220, 13, 18),
    ),
  ),
])

///|
let style_input_row : String = @respo_node.static_style([
  ("&", @css.respo_style(display=Flex, gap=Px(8), margin_bottom=Px(16))),
])

///|
let style_input : String = @respo_node.static_style([
  (
    "&",
    @css.respo_style(
      flex=1.0,
      padding=Px(12),
      font_size=16,
      border=@css.CssBorder::new(width=1.0, style=Solid, color=Hsl(220, 13, 80)),
      border_radius=6.0,
      outline=@css.CssOutline::None,
    ),
  ),
])

///|
let style_button : String = @respo_node.static_style([
  (
    "&",
    @css.respo_style(
      padding_left=Px(24),
      padding_right=Px(24),
      padding_top=Px(12),
      padding_bottom=Px(12),
      font_size=16,
      font_weight="600",
      background_color=Hsl(220, 90, 56),
      color=White,
      border_width=Px(0),
      border_radius=6.0,
      cursor=Pointer,
    ),
  ),
])

///|
let style_error : String = @respo_node.static_style([
  (
    "&",
    @css.respo_style(
      padding=Px(12),
      margin_bottom=Px(16),
      background_color=Hsl(0, 80, 95),
      color=Hsl(0, 70, 40),
      border_radius=6.0,
      border=@css.CssBorder::new(width=1.0, style=Solid, color=Hsl(0, 70, 80)),
    ),
  ),
])

///|
let style_result : String = @respo_node.static_style([
  (
    "&",
    @css.respo_style(
      padding=Px(16),
      background_color=Hsl(220, 14, 96),
      border_radius=8.0,
      white_space="pre-wrap",
      line_height=Em(1.6),
      font_size=15,
    ),
  ),
])

///|
let style_loading : String = @respo_node.static_style([
  (
    "&",
    @css.respo_style(padding=Px(16), color=Hsl(220, 13, 50), font_style=Italic),
  ),
])
