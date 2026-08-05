// Cloudflare Pages API endpoint for Native App Version Check (/api/version)
export async function onRequest(context) {
  const versionData = {
    version: "1.0.1",
    build_number: 2,
    release_notes: "Bổ sung cơ chế tự động kiểm tra bản mới, lưu vết tên người vận hành và tối ưu giao diện.",
    published_at: new Date().toISOString(),
    download_urls: {
      windows: "https://github.com/Thuong180702/oht-controll/releases/latest",
      android: "https://github.com/Thuong180702/oht-controll/releases/latest",
      macOS: "https://github.com/Thuong180702/oht-controll/releases/latest",
      linux: "https://github.com/Thuong180702/oht-controll/releases/latest",
      html: "https://oht-control.pages.dev"
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
