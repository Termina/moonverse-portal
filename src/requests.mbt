// FFI for fetch

///|
type JSResponse

///|
type JSJson

///|
extern "js" fn fetch(
  url : String,
  options : @dom_ffi.JsObscure,
) -> @js_async.Promise[JSResponse] =
  #| (url, options) => fetch(url, options)

///|
extern "js" fn JSResponse::json(self : JSResponse) -> @js_async.Promise[JSJson] =
  #| (self) => self.json()

///|
extern "js" fn JSResponse::text(self : JSResponse) -> @js_async.Promise[String] =
  #| (self) => self.text()

///|
extern "js" fn JSResponse::status(self : JSResponse) -> Int =
  #| (self) => self.status

///|
extern "js" fn JSResponse::ok(self : JSResponse) -> Bool =
  #| (self) => self.ok

// Helper to create fetch options

///|
extern "js" fn make_post_options(body : String) -> @dom_ffi.JsObscure =
  #| (body) => ({ method: "POST", body: body, headers: { "Content-Type": "application/json" } })

///|
extern "js" fn make_get_options() -> @dom_ffi.JsObscure =
  #| () => ({ method: "GET" })

// Helper to parse JSJson

///|
extern "js" fn get_id(json : JSJson) -> String =
  #| (json) => json.id

///|
extern "js" fn get_status(json : JSJson) -> String =
  #| (json) => json.status

///|
extern "js" fn get_result(json : JSJson) -> String =
  #| (json) => json.result

///|
extern "js" fn sleep(ms : Int) -> @js_async.Promise[Unit] =
  #| (ms) => new Promise(resolve => setTimeout(resolve, ms))

// Async function to run the query

///|
pub async fn run_query(prompt : String) -> String raise Failure {
  let body = "{\"prompt\": \"" + prompt + "\", \"mode\": \"hybrid\"}"
  let options = make_post_options(body)

  // POST /query
  let resp = fetch("http://localhost:8080/query", options).wait() catch {
    error => raise Failure("Fetch failed: " + error.to_string())
  }
  if not(resp.ok()) {
    raise Failure("Failed to start query: " + resp.status().to_string())
  }
  let json_resp = resp.json().wait() catch {
      error => raise Failure("JSON parse failed: " + error.to_string())
    }
  let id = get_id(json_resp)

  // Poll /query/{id}
  while true {
    let poll_resp = fetch(
      "http://localhost:8080/query/" + id,
      make_get_options(),
    ).wait() catch {
      error => raise Failure("Poll fetch failed: " + error.to_string())
    }
    if not(poll_resp.ok()) {
      raise Failure("Failed to poll query: " + poll_resp.status().to_string())
    }
    let poll_json = poll_resp.json().wait() catch {
        error => raise Failure("Poll JSON parse failed: " + error.to_string())
      }
    let status = get_status(poll_json)
    if status == "done" {
      break get_result(poll_json)
    } else if status == "error" {
      raise Failure("Query failed")
    }
    sleep(1000).wait() catch {
      _ => ()
    }
  } else {
    raise Failure("Unreachable")
  }
}
