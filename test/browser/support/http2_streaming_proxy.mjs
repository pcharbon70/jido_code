import fs from "node:fs";
import http from "node:http";
import http2 from "node:http2";

const listenPort = Number(process.env.HUI_B4_HTTP2_PROXY_PORT || 4415);
const upstreamPort = Number(process.env.HUI_B3_UPSTREAM_PORT || 4413);
const key = fs.readFileSync("test/browser/support/hui-b4-local.key");
const cert = fs.readFileSync("test/browser/support/hui-b4-local.crt");

const connectionHeaders = new Set([
  "connection",
  "keep-alive",
  "proxy-connection",
  "transfer-encoding",
  "upgrade",
]);

const server = http2.createSecureServer(
  { allowHTTP1: false, key, cert },
  (request, response) => {
    if (request.url === "/__proxy_health") {
      response.writeHead(200, {
        "content-type": "text/plain",
        "x-hui-b4-ingress-protocol": `h${request.httpVersionMajor}`,
      });
      response.end("ready");
      return;
    }

    const headers = Object.fromEntries(
      Object.entries(request.headers).filter(
        ([name]) => !name.startsWith(":") && !connectionHeaders.has(name)
      )
    );
    delete headers["accept-encoding"];
    headers.host = `127.0.0.1:${upstreamPort}`;
    headers["x-forwarded-for"] = request.socket.remoteAddress || "127.0.0.1";
    headers["x-forwarded-host"] = `127.0.0.1:${listenPort}`;
    headers["x-forwarded-proto"] = "https";

    if (headers.origin) {
      headers.origin = `http://127.0.0.1:${upstreamPort}`;
    }

    const upstream = http.request(
      {
        hostname: "127.0.0.1",
        port: upstreamPort,
        path: request.url,
        method: request.method,
        headers,
      },
      (upstreamResponse) => {
        const responseHeaders = Object.fromEntries(
          Object.entries(upstreamResponse.headers).filter(
            ([name]) => !connectionHeaders.has(name)
          )
        );
        responseHeaders["x-hui-b3-proxy"] = "streaming-pass-through";
        responseHeaders["x-hui-b4-ingress-protocol"] =
          `h${request.httpVersionMajor}`;

        const contentType = upstreamResponse.headers["content-type"] || "";

        if (
          contentType.startsWith("text/event-stream")
        ) {
          responseHeaders["x-accel-buffering"] = "no";
          responseHeaders["x-hui-b3-proxy-mode"] = "unbuffered-sse";
        }

        if (contentType.startsWith("text/html")) {
          const chunks = [];
          upstreamResponse.on("data", (chunk) => chunks.push(chunk));
          upstreamResponse.on("end", () => {
            const upstreamOrigin = `http://127.0.0.1:${upstreamPort}/`;
            const body = Buffer.concat(chunks)
              .toString("utf8")
              .replaceAll(upstreamOrigin, "/");
            delete responseHeaders["content-length"];
            response.writeHead(
              upstreamResponse.statusCode || 502,
              responseHeaders
            );
            response.end(body);
          });
        } else {
          response.writeHead(
            upstreamResponse.statusCode || 502,
            responseHeaders
          );
          response.flushHeaders();
          upstreamResponse.pipe(response);
        }
      }
    );

    upstream.on("error", () => {
      if (!response.headersSent) {
        response.writeHead(502, { "content-type": "application/json" });
      }
      response.end('{"error":"proxy_upstream_unavailable"}');
    });

    request.pipe(upstream);
  }
);

server.listen(listenPort, "127.0.0.1");

for (const signal of ["SIGINT", "SIGTERM"]) {
  process.on(signal, () => server.close(() => process.exit(0)));
}
