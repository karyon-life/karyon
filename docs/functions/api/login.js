export async function onRequestPost(context) {
    const { request, env } = context;
    
    try {
        const { password } = await request.json();
        const expectedPassword = env.KARYON_PASSWORD;

        if (!expectedPassword) {
            return new Response(JSON.stringify({ error: "Server configuration error: KARYON_PASSWORD not set." }), { 
                status: 500,
                headers: { "Content-Type": "application/json" }
            });
        }

        if (password === expectedPassword) {
            // Set an HttpOnly session cookie
            return new Response(JSON.stringify({ success: true }), {
                status: 200,
                headers: {
                    "Content-Type": "application/json",
                    "Set-Cookie": "karyon_auth=true; Path=/; HttpOnly; SameSite=Lax; Max-Age=86400" // 24 hours
                }
            });
        }

        return new Response(JSON.stringify({ error: "Invalid password" }), { 
            status: 401,
            headers: { "Content-Type": "application/json" }
        });

    } catch (err) {
        return new Response(JSON.stringify({ error: "Malformed request" }), { 
            status: 400,
            headers: { "Content-Type": "application/json" }
        });
    }
}
