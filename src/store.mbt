///|
/// 代码文件搜索详情
struct CodeFileDetail {
  path : String // 文件路径
  match_count : Int // 匹配行数
  preview : String // 内容预览
} derive(Default, Eq, ToJson, @json.FromJson)

///|
/// 文档文件详情
struct DocFileDetail {
  name : String // 文件名
  file_type : String // MIME 类型
  preview : String // 内容预览（可选）
} derive(Default, Eq, ToJson, @json.FromJson)

///|
/// 查询统计信息
struct QueryStats {
  llm_calls : Int // LLM 调用次数
  search_calls : Int // 搜索调用次数
  tool_calls : Int // 工具调用次数
} derive(Default, Eq, ToJson, @json.FromJson)

///|
/// 查询进度信息
struct QueryProgress {
  phase : String // initializing, searching-code, searching-docs, analyzing, generating, complete
  message : String // 当前进度消息
  code_results_count : Int // 找到的代码匹配数
  docs_results_count : Int // 使用的文档数
  partial_content : String // 部分结果或额外信息
  code_files : Array[String] // 匹配的代码文件列表
  docs_files : Array[String] // 使用的文档文件列表
  code_search_details : Array[CodeFileDetail] // 代码搜索详情
  docs_search_details : Array[DocFileDetail] // 文档详情
  stats : QueryStats // 统计信息
} derive(Default, Eq, ToJson, @json.FromJson)

///|
struct HistoryItem {
  id : Int
  query : String
  result : String
  error : String
  loading : Bool
  progress : QueryProgress // 进度信息
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
  QueryProgress(Int, QueryProgress) // Update progress for a query
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
    QueryProgress(id, progress) =>
      "QueryProgress(\{id}, \{progress.phase}: \{progress.message})"
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
        progress: {
          phase: "initializing",
          message: "正在初始化查询...",
          code_results_count: 0,
          docs_results_count: 0,
          partial_content: "",
          code_files: [],
          docs_files: [],
          code_search_details: [],
          docs_search_details: [],
          stats: QueryStats::default(),
        },
      }
      let new_history = self.history.copy()
      new_history.push(item)
      { ..self, history: new_history, current_id: Some(id), next_id: id + 1 }
    }
    QueryProgress(id, progress) => {
      let new_history = self.history.map(fn(item) {
        if item.id == id {
          { ..item, progress, }
        } else {
          item
        }
      })
      { ..self, history: new_history }
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
