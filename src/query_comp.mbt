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
    // 使用纯 JS 实现的异步请求
    run_query_js(
      prompt,
      fn(result) {
        println("Query success, result length: \{result.length()}")
        dispatch.set_state(cursor, QueryState::{
          input_val: prompt,
          loading: false,
        }) catch {
          _ => ()
        }
        dispatch.run(QuerySuccess(result)) catch {
          _ => ()
        }
        @respo.mark_need_rerender()
      },
      fn(err) {
        println("Query error: \{err}")
        dispatch.set_state(cursor, QueryState::{
          input_val: prompt,
          loading: false,
        }) catch {
          _ => ()
        }
        dispatch.run(QueryError(err)) catch {
          _ => ()
        }
        @respo.mark_need_rerender()
      },
    )
    println("start_query_request: after run_query_js")
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
      @respo_node.div(class_name=style_result, [@markdown.comp_md_block(result)])
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
