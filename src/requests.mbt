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

///|
/// Helper to schedule an async function to run on the next tick
extern "js" fn schedule_async(promise : @js_async.Promise[Unit]) -> Unit =
  #| (p) => { p.then(() => {}).catch(e => console.error("Async error:", e)); }

///|
/// Run query using pure JS async - bypassing MoonBit async issues
extern "js" fn run_query_js(
  prompt : String,
  on_success : (String) -> Unit,
  on_error : (String) -> Unit,
) -> Unit =
  #| async (prompt, onSuccess, onError) => {
  #|   try {
  #|     const params = new URLSearchParams(window.location.search);
  #|     const isDev = params.get("mode") === "dev";
  #|     const baseUrl = isDev ? "http://localhost:8080" : "https://moonverse-api.tiye.me";
  #|     console.log("run_query_js: using baseUrl:", baseUrl, "isDev:", isDev);
  #|     console.log("run_query_js: starting with prompt:", prompt);
  #|     const body = JSON.stringify({ type: "hybrid", query: prompt });
  #|     const resp = await fetch(baseUrl + "/query", {
  #|       method: "POST",
  #|       headers: { "Content-Type": "application/json" },
  #|       body
  #|     });
  #|     console.log("run_query_js: POST response status:", resp.status);
  #|     if (!resp.ok) {
  #|       onError("Failed to start query: " + resp.status);
  #|       return;
  #|     }
  #|     const json = await resp.json();
  #|     const id = json.id;
  #|     console.log("run_query_js: got task id:", id);
  #|     while (true) {
  #|       console.log("run_query_js: polling /query/" + id);
  #|       const pollResp = await fetch(baseUrl + "/query/" + id);
  #|       if (!pollResp.ok) {
  #|         onError("Failed to poll: " + pollResp.status);
  #|         return;
  #|       }
  #|       const pollJson = await pollResp.json();
  #|       console.log("run_query_js: poll status:", pollJson.status);
  #|       if (pollJson.status === "done") {
  #|         onSuccess(pollJson.content || pollJson.result || "");
  #|         return;
  #|       } else if (pollJson.status === "error") {
  #|         onError(pollJson.error || "Query failed");
  #|         return;
  #|       }
  #|       await new Promise(r => setTimeout(r, 1000));
  #|     }
  #|   } catch (e) {
  #|     console.error("run_query_js error:", e);
  #|     onError(e.toString());
  #|   }
  #| }

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
