export async function onRequest(context) {
    const { request, env, next } = context;
    const url = new URL(request.url);

    // Bypass protection for login page, assets, and the login API itself
    if (
        url.pathname === "/login" || 
        url.pathname === "/login.html" || 
        url.pathname.startsWith("/api/") || 
        url.pathname.startsWith("/_astro/") || 
        url.pathname.includes(".") // Simple way to bypass static files like .png, .css
    ) {
        return next();
    }

    // Check for session cookie
    const cookie = request.headers.get("Cookie") || "";
    if (cookie.includes("karyon_auth=true")) {
        return next();
    }

    // Redirect to login page if not authenticated
    return Response.redirect(`${url.origin}/login?from=${encodeURIComponent(url.pathname)}`, 302);
}
