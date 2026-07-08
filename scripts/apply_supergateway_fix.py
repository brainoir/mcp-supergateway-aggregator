import sys

def apply_fix():
    file_path1 = "/usr/local/lib/node_modules/supergateway/dist/gateways/stdioToStatelessStreamableHttp.js"
    file_path2 = "/usr/lib/node_modules/supergateway/dist/gateways/stdioToStatelessStreamableHttp.js"
    
    file_path = None
    import os
    if os.path.exists(file_path1):
        file_path = file_path1
    elif os.path.exists(file_path2):
        file_path = file_path2
        
    if not file_path:
        print("File not found! Make sure supergateway is installed.")
        sys.exit(1)
        
    try:
        with open(file_path, "r", encoding="utf-8") as f:
            content = f.read()
    except Exception as e:
        print("Error reading file:", e)
        sys.exit(1)

    # 1. Add imports
    content = content.replace(
        "import { spawn } from 'child_process';",
        "import { spawn } from 'child_process';"
    )

    # 2. Add functions
    functions_code = """
const reapGraceMs = () => {
    const g = Number(process.env.SUPERGATEWAY_REAP_GRACE_MS);
    return Number.isFinite(g) && g >= 0 ? g : 2000;
};
const reapRequestSession = (pgid, signal) => {
    try {
        process.kill(-pgid, signal);
    } catch (e) {
    }
};
"""
    if "reapGraceMs =" not in content:
        content = content.replace(
            "const setResponseHeaders =",
            functions_code + "\nconst setResponseHeaders ="
        )

    # 3. Spawn detached and reap logic
    old_spawn = "const child = spawn(stdioCmd, { shell: true });"
    new_spawn = """const child = spawn(stdioCmd, { shell: true, detached: true });
            let reaped = false;
            const reapChild = () => {
                if (reaped) return;
                reaped = true;
                const pgid = child.pid;
                if (typeof pgid !== 'number') return;
                try { process.kill(-pgid, 'SIGTERM'); } catch { }
                const t = setTimeout(() => reapRequestSession(pgid, 'SIGKILL'), reapGraceMs());
                if (t.unref) t.unref();
            };
            res.on('close', reapChild);
            res.on('finish', reapChild);"""
    content = content.replace(old_spawn, new_spawn)

    # 4. Exit handler
    old_exit = """child.on('exit', (code, signal) => {
                logger.error(`Child exited: code=${code}, signal=${signal}`);
                transport.close();
            });"""
    new_exit = """child.on('exit', (code, signal) => {
                logger.error(`Child exited: code=${code}, signal=${signal}`);
                reaped = true;
                if (!res.headersSent) {
                    try {
                        res.status(502).json({
                            jsonrpc: '2.0',
                            error: {
                                code: -32000,
                                message: `MCP child exited before response (code=${code}, signal=${signal})`,
                            },
                            id: null,
                        });
                    } catch { }
                }
                transport.close();
            });"""
    content = content.replace(old_exit, new_exit)

    # 5. transport.send fix
    old_send = """try {
                            transport.send(jsonMsg);
                        }
                        catch (e) {
                            logger.error(`Failed to send to StreamableHttp`, e);
                        }"""
    new_send = """Promise.resolve(transport.send(jsonMsg)).catch((e) => {
                            logger.error(`Failed to send to StreamableHttp`, e);
                        });"""
    content = content.replace(old_send, new_send)

    with open(file_path, "w", encoding="utf-8") as f:
        f.write(content)

    print("Successfully applied supergateway fix!")

if __name__ == "__main__":
    apply_fix()
