///|
struct QueryState {
  input_val : String
} derive(Default, ToJson, @json.FromJson)

///|
fn comp_query(
  states : @respo.RespoStatesTree,
  loading : Bool,
  result : String,
  error : String,
) -> @respo_node.RespoNode[ActionOp] {
  let cursor = states.path()
  let state = (states.cast_branch() : QueryState)
  @respo_node.div(
    class_name="query-comp",
    style=@css.respo_style(padding=Px(12)),
    [
      @respo_node.div([
        @respo_node.input(
          value=state.input_val,
          placeholder="Enter prompt...",
          on_input=fn(e, dispatch) {
            match e {
              Input(value~, ..) =>
                dispatch.set_state(cursor, { input_val: value })
              _ => ()
            }
          },
          style=@css.respo_style(width=Px(300), margin_right=Px(8)),
        ),
        @respo_node.button(
          inner_text=if loading { "Loading..." } else { "Submit" },
          attrs={ "disabled": if loading { "true" } else { "false" } },
          on_click=fn(_e, dispatch) {
            if not(loading) && not(state.input_val.is_empty()) {
              dispatch.run(StartQuery(state.input_val))
            }
          },
        ),
      ]),
      if not(error.is_empty()) {
        @respo_node.div(style=@css.respo_style(color=Red, margin_top=Px(8)), [
          @respo_node.text_node(error),
        ])
      } else {
        @respo_node.span([])
      },
      if not(result.is_empty()) {
        @respo_node.div(
          style=@css.respo_style(margin_top=Px(8), white_space="pre-wrap"),
          [@respo_node.text_node(result)],
        )
      } else {
        @respo_node.span([])
      },
    ],
  )
}
