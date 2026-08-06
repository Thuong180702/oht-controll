// Cloudflare Pages API endpoint for Native App Version Check (/api/version)
export async function onRequest(context) {
  const versionData = {
    version: "1.0.4",
    build_number: 5,
    release_notes: "Bản cập nhật v1.0.4: Nâng cấp Unit ID thành 1807-VIP, nâng cấp hệ thống tự động cập nhật ngầm đa nền tảng (Windows, Android, macOS, Linux, Web).",
    published_at: new Date().toISOString(),
    download_urls: {
      windows: "https://github.com/Thuong180702/oht-controll/releases/latest",
      android: "https://github.com/Thuong180702/oht-controll/releases/latest",
      macOS: "https://github.com/Thuong180702/oht-controll/releases/latest",
      linux: "https://github.com/Thuong180702/oht-controll/releases/latest",
      html: "https://robot-controller-remote.pages.dev"
    }
  };

  return new Response(JSON.stringify(versionData), {
    headers: {
      "Content-Type": "application/json; charset=utf-8",
      "Access-Control-Allow-Origin": "*",
      "Cache-Control": "no-cache, no-store, must-revalidate"
    }
  });
}
