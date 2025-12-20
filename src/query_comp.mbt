///|
struct QueryState {
  input_val : String
} derive(Default, ToJson, @json.FromJson)

///|
/// Copy helper keeps a raw markdown record for debugging in UI.
extern "js" fn copy_to_clipboard(text : String) -> Unit =
  #| (text) => {
  #|   const safeText = text ?? "";
  #|   if (typeof navigator !== "undefined" && navigator.clipboard?.writeText) {
  #|     navigator.clipboard.writeText(safeText).catch(err => {
  #|       console.warn("Clipboard write failed", err);
  #|     });
  #|     return;
  #|   }
  #|   const textarea = document.createElement("textarea");
  #|   textarea.value = safeText;
  #|   textarea.style.position = "fixed";
  #|   textarea.style.opacity = "0";
  #|   textarea.style.pointerEvents = "none";
  #|   document.body.appendChild(textarea);
  #|   textarea.focus();
  #|   textarea.select();
  #|   try {
  #|     document.execCommand("copy");
  #|   } catch (err) {
  #|     console.error("execCommand copy failed", err);
  #|   } finally {
  #|     document.body.removeChild(textarea);
  #|   }
  #| }

///|
fn comp_app(
  states : @respo.RespoStatesTree,
  store : Store,
) -> @respo_node.RespoNode[ActionOp] {
  @respo_node.div(class_name=style_app_container, [
    // 左侧边栏
    comp_sidebar(store),
    // 右侧主区域
    comp_main_area(states, store),
  ])
}

///|
fn comp_sidebar(store : Store) -> @respo_node.RespoNode[ActionOp] {
  @respo_node.div(class_name=style_sidebar, [
    // 侧边栏标题和新建按钮
    @respo_node.div(class_name=style_sidebar_header, [
      @respo_node.div(class_name=style_sidebar_title, [
        @respo_node.text_node("History"),
      ]),
      @respo_node.button(inner_text="+ New", class_name=style_new_button, on_click=fn(
        _e,
        dispatch,
      ) {
        dispatch.run(NewQuery)
      }),
    ]),
    // 历史记录列表
    @respo_node.div(
      class_name=style_history_list,
      store.history
      .rev_iter()
      .map(fn(item) { comp_history_item(item, store.current_id) })
      .collect(),
    ),
  ])
}

///|
fn comp_history_item(
  item : HistoryItem,
  current_id : Int?,
) -> @respo_node.RespoNode[ActionOp] {
  let is_selected = current_id == Some(item.id)
  let preview = if item.query.length() > 30 {
    (try! item.query[:30]).to_string() + "..."
  } else {
    item.query
  }
  @respo_node.div(
    class_name=if is_selected {
      style_history_item_selected
    } else {
      style_history_item
    },
    on_click=fn(_e, dispatch) { dispatch.run(SelectQuery(item.id)) },
    [
      @respo_node.div(class_name=style_history_item_content, [
        @respo_node.div(class_name=style_history_preview, [
          @respo_node.text_node(preview),
        ]),
        if item.loading {
          @respo_node.div(class_name=style_history_status, [
            @respo_node.text_node("⏳"),
          ])
        } else if not(item.error.is_empty()) {
          @respo_node.div(class_name=style_history_status_error, [
            @respo_node.text_node("❌"),
          ])
        } else {
          @respo_node.div(class_name=style_history_status_ok, [
            @respo_node.text_node("✓"),
          ])
        },
      ]),
      @respo_node.button(inner_text="×", class_name=style_delete_button, on_click=fn(
        _e,
        dispatch,
      ) {
        dispatch.run(DeleteQuery(item.id))
      }),
    ],
  )
}

///|
fn comp_main_area(
  states : @respo.RespoStatesTree,
  store : Store,
) -> @respo_node.RespoNode[ActionOp] {
  match store.current_id {
    None => comp_new_query(states)
    Some(id) =>
      match store.history.iter().find_first(fn(item) { item.id == id }) {
        Some(item) => comp_query_detail(item)
        None => comp_new_query(states)
      }
  }
}

///|
fn comp_new_query(
  states : @respo.RespoStatesTree,
) -> @respo_node.RespoNode[ActionOp] {
  let cursor = states.path()
  let state = (states.cast_branch() : QueryState)
  @respo_node.div(class_name=style_main_area, [
    @respo_node.div(class_name=style_new_query_container, [
      @respo_node.div(class_name=style_main_title, [
        @respo_node.text_node("MoonBit Query"),
      ]),
      @respo_node.div(class_name=style_input_container, [
        @respo_node.textarea(
          value=state.input_val,
          placeholder="Enter your question about MoonBit...",
          class_name=style_textarea,
          on_input=fn(e, dispatch) {
            match e {
              Input(value~, ..) =>
                dispatch.set_state(cursor, QueryState::{ input_val: value })
              _ => ()
            }
          },
        ),
      ]),
      @respo_node.div(class_name=style_button_row, [
        @respo_node.button(
          inner_text="Submit",
          class_name=style_submit_button,
          on_click=fn(_e, dispatch) {
            if not(state.input_val.is_empty()) {
              let prompt = state.input_val
              dispatch.run(StartQuery(prompt))
              // Clear input after submit
              dispatch.set_state(cursor, QueryState::{ input_val: "" }) catch {
                _ => ()
              }
            }
          },
        ),
      ]),
    ]),
  ])
}

///|
fn comp_query_detail(item : HistoryItem) -> @respo_node.RespoNode[ActionOp] {
  @respo_node.div(class_name=style_main_area, [
    // 显示查询内容（只读）
    @respo_node.div(class_name=style_query_display, [
      @respo_node.div(class_name=style_query_label, [
        @respo_node.text_node("Query:"),
      ]),
      @respo_node.div(class_name=style_query_text, [
        @respo_node.text_node(item.query),
      ]),
    ]),
    // 结果或加载状态
    if item.loading {
      @respo_node.div(class_name=style_loading, [
        @respo_node.text_node("Thinking..."),
      ])
    } else if not(item.error.is_empty()) {
      @respo_node.div(class_name=style_error, [
        @respo_node.text_node(item.error),
      ])
    } else if not(item.result.is_empty()) {
      @respo_node.div(class_name=style_result_container, [
        @respo_node.div(class_name=style_result, [
          @markdown.comp_md_block(item.result),
        ]),
        @respo_node.button(
          inner_text="Copy Raw Markdown",
          class_name=style_copy_button,
          on_click=fn(_e, _dispatch) {
            copy_to_clipboard(item.result)
            println("Copied markdown to clipboard")
          },
        ),
      ])
    } else {
      @respo_node.span([])
    },
  ])
}

// ============= Styles =============

///|
let style_app_container : String = @respo_node.static_style([
  (
    "&",
    @css.respo_style(
      display=Flex,
      height=Vh(100),
      font_family="system-ui, -apple-system, sans-serif",
    ),
  ),
])

///|
let style_sidebar : String = @respo_node.static_style([
  (
    "&",
    @css.respo_style(
      width=Px(280),
      min_width=Px(280),
      background_color=Hsl(220, 14, 96),
      display=Flex,
      flex_direction=Column,
    )
    .add("border-right", "1px solid hsl(220, 13%, 88%)")
    .add("overflow-y", "auto"),
  ),
])

///|
let style_sidebar_header : String = @respo_node.static_style([
  (
    "&",
    @css.respo_style(
      padding=Px(16),
      display=Flex,
      justify_content=SpaceBetween,
      align_items=Center,
    ).add("border-bottom", "1px solid hsl(220, 13%, 88%)"),
  ),
])

///|
let style_sidebar_title : String = @respo_node.static_style([
  (
    "&",
    @css.respo_style(font_size=16, font_weight="600", color=Hsl(220, 13, 30)),
  ),
])

///|
let style_new_button : String = @respo_node.static_style([
  (
    "&",
    @css.respo_style(
      padding_left=Px(12),
      padding_right=Px(12),
      padding_top=Px(6),
      padding_bottom=Px(6),
      font_size=14,
      background_color=Hsl(220, 90, 56),
      color=White,
      border_width=Px(0),
      border_radius=4.0,
      cursor=Pointer,
    ),
  ),
])

///|
let style_history_list : String = @respo_node.static_style([
  ("&", @css.respo_style(flex=1.0, padding=Px(8)).add("overflow-y", "auto")),
])

///|
let style_history_item : String = @respo_node.static_style([
  (
    "&",
    @css.respo_style(
      display=Flex,
      align_items=Center,
      padding=Px(10),
      margin_bottom=Px(4),
      border_radius=6.0,
      cursor=Pointer,
      background_color=Transparent,
    ),
  ),
  ("&:hover", @css.respo_style(background_color=Hsl(220, 14, 92))),
])

///|
let style_history_item_selected : String = @respo_node.static_style([
  (
    "&",
    @css.respo_style(
      display=Flex,
      align_items=Center,
      padding=Px(10),
      margin_bottom=Px(4),
      border_radius=6.0,
      cursor=Pointer,
      background_color=Hsl(220, 90, 95),
      border=@css.CssBorder::new(width=1.0, style=Solid, color=Hsl(220, 90, 56)),
    ),
  ),
])

///|
let style_history_item_content : String = @respo_node.static_style([
  (
    "&",
    @css.respo_style(flex=1.0, display=Flex, align_items=Center, gap=Px(8)).add(
      "overflow", "hidden",
    ),
  ),
])

///|
let style_history_preview : String = @respo_node.static_style([
  (
    "&",
    @css.respo_style(
      font_size=14,
      color=Hsl(220, 13, 30),
      overflow=Hidden,
      white_space="nowrap",
    )
    .add("text-overflow", "ellipsis")
    .add("flex", "1 1 0")
    .add("min-width", "0"),
  ),
])

///|
let style_history_status : String = @respo_node.static_style([
  ("&", @css.respo_style(font_size=12)),
])

///|
let style_history_status_ok : String = @respo_node.static_style([
  ("&", @css.respo_style(font_size=12, color=Hsl(120, 60, 40))),
])

///|
let style_history_status_error : String = @respo_node.static_style([
  ("&", @css.respo_style(font_size=12, color=Hsl(0, 70, 50))),
])

///|
let style_delete_button : String = @respo_node.static_style([
  (
    "&",
    @css.respo_style(
      padding_left=Px(8),
      padding_right=Px(8),
      padding_top=Px(4),
      padding_bottom=Px(4),
      font_size=16,
      background_color=Transparent,
      color=Hsl(220, 13, 60),
      border_width=Px(0),
      cursor=Pointer,
      opacity=0.6,
    ),
  ),
  ("&:hover", @css.respo_style(opacity=1.0, color=Hsl(0, 70, 50))),
])

///|
let style_main_area : String = @respo_node.static_style([
  (
    "&",
    @css.respo_style(
      flex=1.0,
      display=Flex,
      flex_direction=Column,
      padding=Px(24),
    ).add("overflow-y", "auto"),
  ),
])

///|
let style_new_query_container : String = @respo_node.static_style([
  (
    "&",
    @css.respo_style(
      max_width=Px(800),
      width=Percent(100),
      margin_left=Auto,
      margin_right=Auto,
    ),
  ),
])

///|
let style_main_title : String = @respo_node.static_style([
  (
    "&",
    @css.respo_style(
      font_size=28,
      font_weight="bold",
      margin_bottom=Px(24),
      color=Hsl(220, 13, 18),
    ),
  ),
])

///|
let style_input_container : String = @respo_node.static_style([
  ("&", @css.respo_style(margin_bottom=Px(16))),
])

///|
let style_textarea : String = @respo_node.static_style([
  (
    "&",
    @css.respo_style(
      width=Percent(100),
      padding=Px(16),
      font_size=16,
      line_height=Em(1.6),
      border=@css.CssBorder::new(width=1.0, style=Solid, color=Hsl(220, 13, 80)),
      border_radius=8.0,
      outline=@css.CssOutline::None,
      resize=Vertical,
    ).add("min-height", "150px"),
  ),
  (
    "&:focus",
    @css.respo_style(
      border=@css.CssBorder::new(width=2.0, style=Solid, color=Hsl(220, 90, 56)),
    ),
  ),
])

///|
let style_button_row : String = @respo_node.static_style([
  ("&", @css.respo_style(display=Flex, justify_content=FlexEnd)),
])

///|
let style_submit_button : String = @respo_node.static_style([
  (
    "&",
    @css.respo_style(
      padding_left=Px(32),
      padding_right=Px(32),
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
  ("&:hover", @css.respo_style(background_color=Hsl(220, 90, 50))),
])

///|
let style_query_display : String = @respo_node.static_style([
  (
    "&",
    @css.respo_style(
      margin_bottom=Px(20),
      padding=Px(16),
      background_color=Hsl(220, 14, 97),
      border_radius=8.0,
    ),
  ),
])

///|
let style_query_label : String = @respo_node.static_style([
  (
    "&",
    @css.respo_style(
      font_size=12,
      font_weight="600",
      color=Hsl(220, 13, 50),
      margin_bottom=Px(8),
    ).add("text-transform", "uppercase"),
  ),
])

///|
let style_query_text : String = @respo_node.static_style([
  (
    "&",
    @css.respo_style(
      font_size=16,
      line_height=Em(1.5),
      color=Hsl(220, 13, 20),
      white_space="pre-wrap",
    ),
  ),
])

///|
let style_result_container : String = @respo_node.static_style([
  ("&", @css.respo_style(flex=1.0)),
])

///|
let style_result : String = @respo_node.static_style([
  (
    "&",
    @css.respo_style(
      padding=Px(16),
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
    @css.respo_style(
      padding=Px(24),
      color=Hsl(220, 13, 50),
      font_style=Italic,
      font_size=16,
    ),
  ),
])

///|
let style_error : String = @respo_node.static_style([
  (
    "&",
    @css.respo_style(
      padding=Px(16),
      background_color=Hsl(0, 80, 95),
      color=Hsl(0, 70, 40),
      border_radius=8.0,
      border=@css.CssBorder::new(width=1.0, style=Solid, color=Hsl(0, 70, 80)),
    ),
  ),
])

///|
let style_copy_button : String = @respo_node.static_style([
  (
    "&",
    @css.respo_style(
      margin_top=Px(16),
      padding_left=Px(16),
      padding_right=Px(16),
      padding_top=Px(8),
      padding_bottom=Px(8),
      font_size=13,
      background_color=Hsl(220, 10, 90),
      color=Hsl(220, 13, 30),
      border_width=Px(0),
      border_radius=4.0,
      cursor=Pointer,
    ),
  ),
  ("&:hover", @css.respo_style(background_color=Hsl(220, 10, 85))),
])
