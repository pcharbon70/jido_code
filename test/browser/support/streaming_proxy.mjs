import http from "node:http";

const listenPort = Number(process.env.HUI_B3_PROXY_PORT || 4414);
const upstreamPort = Number(process.env.HUI_B3_UPSTREAM_PORT || 4413);

const server = http.createServer((request, response) => {
  if (request.url === "/__proxy_health") {
    response.writeHead(200, { "content-type": "text/plain" });
    response.end("ready");
    return;
  }

  const headers = {
    ...request.headers,
    "x-forwarded-for": request.socket.remoteAddress || "127.0.0.1",
    "x-forwarded-host": request.headers.host || `127.0.0.1:${listenPort}`,
    "x-forwarded-proto": "http",
  };

  const upstream = http.request(
    {
      hostname: "127.0.0.1",
      port: upstreamPort,
      path: request.url,
      method: request.method,
      headers,
    },
    (upstreamResponse) => {
      const responseHeaders = {
        ...upstreamResponse.headers,
        "x-hui-b3-proxy": "streaming-pass-through",
      };

      if (
        (upstreamResponse.headers["content-type"] || "").startsWith(
          "text/event-stream"
        )
      ) {
        responseHeaders["x-accel-buffering"] = "no";
        responseHeaders["x-hui-b3-proxy-mode"] = "unbuffered-sse";
      }

      response.writeHead(upstreamResponse.statusCode || 502, responseHeaders);
      response.flushHeaders();
      upstreamResponse.pipe(response);
    }
  );

  upstream.on("error", () => {
    if (!response.headersSent) {
      response.writeHead(502, { "content-type": "application/json" });
    }
    response.end('{"error":"proxy_upstream_unavailable"}');
  });

  request.pipe(upstream);
});

server.listen(listenPort, "127.0.0.1");

for (const signal of ["SIGINT", "SIGTERM"]) {
  process.on(signal, () => server.close(() => process.exit(0)));
}
