import { createServer, request as httpRequest } from "node:http";
import { createReadStream, readFileSync } from "node:fs";

const html = readFileSync("/bootstrap/index.html", "utf8");
const invitePath = "/app-data/PAPERCLIP_FIRST_ADMIN_INVITE.txt";
const upstreamHost = "web";
const upstreamPort = 3100;

function respond(res, statusCode, body, headers = {}) {
    res.writeHead(statusCode, {
        "Cache-Control": "no-store",
        ...headers,
    });
    res.end(body);
}

function serveInvite(res) {
    const stream = createReadStream(invitePath);
    stream.on("error", () => {
        respond(res, 404, "Invite file not ready yet.\n", { "Content-Type": "text/plain; charset=utf-8" });
    });
    stream.on("open", () => {
        res.writeHead(200, {
            "Content-Type": "text/plain; charset=utf-8",
            "Cache-Control": "no-store",
        });
    });
    stream.pipe(res);
}

function proxyHttp(req, res) {
    const upstream = httpRequest(
        {
            hostname: upstreamHost,
            port: upstreamPort,
            method: req.method,
            path: req.url,
            headers: {
                ...req.headers,
                host: req.headers.host,
                "x-forwarded-host": req.headers.host,
                "x-forwarded-proto": "http",
            },
        },
        (upstreamRes) => {
            res.writeHead(upstreamRes.statusCode ?? 502, upstreamRes.headers);
            upstreamRes.pipe(res);
        },
    );

    upstream.on("error", (error) => {
        respond(res, 502, `Bootstrap proxy upstream error: ${error.message}\n`, {
            "Content-Type": "text/plain; charset=utf-8",
        });
    });

    req.pipe(upstream);
}

const server = createServer((req, res) => {
    if (!req.url) {
        respond(res, 400, "Missing request URL.\n", { "Content-Type": "text/plain; charset=utf-8" });
        return;
    }

    if (req.url === "/bootstrap-entry") {
        res.writeHead(302, { Location: "/bootstrap-entry/" });
        res.end();
        return;
    }

    if (req.url.startsWith("/bootstrap-entry/")) {
        respond(res, 200, html, { "Content-Type": "text/html; charset=utf-8" });
        return;
    }

    if (req.url === "/__paperclip_invite") {
        serveInvite(res);
        return;
    }

    proxyHttp(req, res);
});

server.on("upgrade", (req, socket, head) => {
    const upstream = httpRequest({
        hostname: upstreamHost,
        port: upstreamPort,
        method: req.method,
        path: req.url,
        headers: {
            ...req.headers,
            host: req.headers.host,
            "x-forwarded-host": req.headers.host,
            "x-forwarded-proto": "http",
        },
    });

    upstream.on("upgrade", (upstreamRes, upstreamSocket, upstreamHead) => {
        const headerLines = Object.entries(upstreamRes.headers)
            .flatMap(([key, value]) =>
                Array.isArray(value) ? value.map((entry) => `${key}: ${entry}`) : [`${key}: ${value}`],
            )
            .join("\r\n");

        socket.write(`HTTP/1.1 101 Switching Protocols\r\n${headerLines}\r\n\r\n`);

        if (head?.length) {
            upstreamSocket.write(head);
        }
        if (upstreamHead?.length) {
            socket.write(upstreamHead);
        }

        upstreamSocket.pipe(socket).pipe(upstreamSocket);
    });

    upstream.on("error", () => {
        socket.destroy();
    });

    upstream.end();
});

server.listen(80, "0.0.0.0");
