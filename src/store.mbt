///|
struct HistoryItem {
  id : Int
  query : String
  result : String
  error : String
  loading : Bool
} derive(Default, Eq, ToJson, @json.FromJson)

///|
struct Store {
  counted : Int
  states : @respo.RespoStatesTree
  history : Array[HistoryItem]
  current_id : Int? // None means new query mode
  next_id : Int
} derive(ToJson, @json.FromJson, Eq)

///|
impl Default for Store with default() -> Store {
  {
    counted: 0,
    states: @respo.RespoStatesTree::default(),
    history: [],
    current_id: None,
    next_id: 1,
  }
}

///|
struct Task {
  id : String
  done : Bool
  content : String
  time : Double
} derive(Default, Eq, Hash, ToJson, @json.FromJson)

///|
enum ActionOp {
  StatesChange(@respo.RespoUpdateState)
  NewQuery // Create new query
  SelectQuery(Int) // Select history item by id
  DeleteQuery(Int) // Delete history item by id
  StartQuery(String) // Start query with prompt
  QuerySuccess(Int, String) // Query success with id and result
  QueryError(Int, String) // Query error with id and error message
}

///|
impl @respo_node.RespoAction for ActionOp with build_states_action(cursor, a, j) {
  StatesChange({ cursor, data: a.map(@dom_ffi.js_obscure_to_v), backup: j })
}

///|
impl Show for ActionOp with output(self, logger) -> Unit {
  let s = match self {
    StatesChange(state) =>
      "StatesChange(\{state.cursor} \{state.backup.to_json()})"
    NewQuery => "NewQuery"
    SelectQuery(id) => "SelectQuery(\{id})"
    DeleteQuery(id) => "DeleteQuery(\{id})"
    StartQuery(prompt) => "StartQuery(\{prompt})"
    QuerySuccess(id, res) => "QuerySuccess(\{id}, \{res.length()} chars)"
    QueryError(id, err) => "QueryError(\{id}, \{err})"
  }
  logger.write_string(s)
}

///|
/// update store immutably
fn Store::update(self : Store, op : ActionOp) -> Store {
  match op {
    StatesChange(states) => { ..self, states: self.states.set_in(states) }
    NewQuery => { ..self, current_id: None }
    SelectQuery(id) => { ..self, current_id: Some(id) }
    DeleteQuery(id) => {
      let new_history = self.history.filter(fn(item) { item.id != id })
      let new_current = if self.current_id == Some(id) {
        None
      } else {
        self.current_id
      }
      { ..self, history: new_history, current_id: new_current }
    }
    StartQuery(prompt) => {
      let id = self.next_id
      let item : HistoryItem = {
        id,
        query: prompt,
        result: "",
        error: "",
        loading: true,
      }
      let new_history = self.history.copy()
      new_history.push(item)
      { ..self, history: new_history, current_id: Some(id), next_id: id + 1 }
    }
    QuerySuccess(id, res) => {
      let new_history = self.history.map(fn(item) {
        if item.id == id {
          { ..item, result: res, loading: false }
        } else {
          item
        }
      })
      { ..self, history: new_history }
    }
    QueryError(id, err) => {
      let new_history = self.history.map(fn(item) {
        if item.id == id {
          { ..item, error: err, loading: false }
        } else {
          item
        }
      })
      { ..self, history: new_history }
    }
  }
}
