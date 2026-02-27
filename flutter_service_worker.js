'use strict';
const MANIFEST = 'flutter-app-manifest';
const TEMP = 'flutter-temp-cache';
const CACHE_NAME = 'flutter-app-cache';

const RESOURCES = {"favicon.png": "5dcef449791fa27946b3d35ad8803796",
"assets/assets/Avatar/female-3.png": "38088d8c42f1514c3ca182770f6ce559",
"assets/assets/Avatar/female-5.png": "aa09c99a6af8951535b9f352c6509aa5",
"assets/assets/Avatar/male-1.png": "d4841ed0793825971b1ce8b22fb6a29b",
"assets/assets/Avatar/male-5.png": "de4fcf1520f60bbaa5368edb0b91ab09",
"assets/assets/Avatar/female-4.png": "4ac2805258378c716ecfabd608038f2b",
"assets/assets/Avatar/default-avatar.svg": "c4742198ab67498d841ace32aaa3e900",
"assets/assets/Avatar/male-4.png": "528bc0a804eff7db0b232007c595a38b",
"assets/assets/Avatar/default-avatar.png": "c9cd454ad9d081920aef0d74be238aa3",
"assets/assets/Avatar/male-3.png": "940fd2b538b42f58901e167a4a9b8151",
"assets/assets/Avatar/female-1.png": "9ac34d609ce63772004f59b0054e3d10",
"assets/assets/Avatar/female-2.png": "7df061313343f50941b368fe340d1b60",
"assets/assets/Avatar/male-6.png": "02bcde73144f09aeb03b3f7deac29486",
"assets/assets/Avatar/male-2.png": "b2ccb00d5a5709b71b6e05399136d71d",
"assets/assets/logos/logoTypo.svg": "05e8a46ce174466a71bc92b6cad7b9c9",
"assets/assets/logo.png": "2b0ab99134965e4577102d7c840046d7",
"assets/assets/elements/Avatar.jpg": "b0fe18d0aa3e31f7051985aac298e5e1",
"assets/assets/elements/Frame.svg": "32eafb50d59c234e432697b003d2f812",
"assets/assets/images/Group.svg": "6d9c7e6b5282b2dd759d6f5d0c8c427a",
"assets/assets/images/Group-1.svg": "a91bfb2be02968f4df15c9e872c13f71",
"assets/assets/images/dabbler_logo.svg": "a91bfb2be02968f4df15c9e872c13f71",
"assets/assets/images/logoTypo.svg": "419d2ea89ae863d6bd33bd87525f76ad",
"assets/assets/images/Home%2520Screen.png": "b67cd75ba21a01dcc39da1d8808216d7",
"assets/assets/images/undraw/empty_friends.svg": "956f4921181ef0d69a6e4d47611a59fb",
"assets/assets/images/undraw/empty_post.svg": "1c5e440bec3e0d5d762536c1dc7e2e34",
"assets/assets/images/undraw/walking-outside.svg": "3982fe3f8e018201b8d447913015f0c2",
"assets/assets/images/dabbler_text_logo.svg": "6d9c7e6b5282b2dd759d6f5d0c8c427a",
"assets/supabase/schema/schema.json": "9473be3ef97c0ac88dbe92f11a521f4c",
"assets/lib/design_system/tokens/DART_TOKENS.md": "e09edefa2b342fbaa7bfb80facec2f5a",
"assets/lib/design_system/tokens/main-dark-theme.json": "5576e30587fdfe9174217e529869cec3",
"assets/lib/design_system/tokens/profile_light.dart": "ca941bdf12154875081b5fbb784e668b",
"assets/lib/design_system/tokens/social-dark-theme.json": "a01e08bab8252b13a8179ba164c9337a",
"assets/lib/design_system/tokens/main_light.dart": "30885ba51daba6570f15abb0f9d4f4c7",
"assets/lib/design_system/tokens/README.md": "bc90de80b6beeb29b31b02c586d4f950",
"assets/lib/design_system/tokens/sports-dark-theme.json": "0968c3a7fd7ca38152b43471765fc580",
"assets/lib/design_system/tokens/activity_light.dart": "301101f65f7ec3d556039d095eb6442f",
"assets/lib/design_system/tokens/sports_dark.dart": "78882b8ebbd3acbac2db7c120d425fe1",
"assets/lib/design_system/tokens/activity_dark.dart": "4c3fd93349295322b89bdf82cb798197",
"assets/lib/design_system/tokens/main-light-theme.json": "1069914a61d66e3091ac29d0e237a6ab",
"assets/lib/design_system/tokens/social_dark.dart": "ffd7e673103a455988543cd42f31b5f9",
"assets/lib/design_system/tokens/profile_dark.dart": "4b00da2ec010f9c1e1ecd5bd14da27a6",
"assets/lib/design_system/tokens/social_light.dart": "4de0348da594406cd526830fb7430960",
"assets/lib/design_system/tokens/social-light-theme.json": "259432bcc8de9fd2057b0bb2bd6505f1",
"assets/lib/design_system/tokens/sports-light-theme.json": "657336423302e3180534ccc439982ca8",
"assets/lib/design_system/tokens/activity-dark-theme.json": "163bbf993ecd4c12e3ce165e5b7b3b2d",
"assets/lib/design_system/tokens/sports_light.dart": "4e4c458029ca159948a58482ddd2da93",
"assets/lib/design_system/tokens/profile-light-theme.json": "0ffcb8af872424458a6f6d5e8679b519",
"assets/lib/design_system/tokens/activity-light-theme.json": "22deef7539b922a611f84327ed49445f",
"assets/lib/design_system/tokens/profile-dark-theme.json": "85d9462d23b5bc585297f5e9b93d8250",
"assets/lib/design_system/tokens/main_dark.dart": "ea702fcaf133f0f9df52d0bc62516790",
"assets/NOTICES": "c876e2beb9c6aebe310e0578b8a9d4c8",
"assets/packages/iconsax_flutter/fonts/FlutterIconsax.ttf": "64db6db352935b2730459ced543c6edb",
"assets/packages/lucide_icons/assets/lucide.ttf": "03f254a55085ec6fe9a7ae1861fda9fd",
"assets/AssetManifest.bin.json": "61579b3eadbddbc6b90dbaf80c4feac2",
"assets/fonts/MaterialIcons-Regular.otf": "656fd3e509b8bc89dc4b2b4cb1e17870",
"assets/shaders/stretch_effect.frag": "40d68efbbf360632f614c731219e95f0",
"assets/shaders/ink_sparkle.frag": "ecc85a2e95f5e9f53123dcaf8cb9b6ce",
"assets/AssetManifest.bin": "e6180c5266bb0dc9e968637809b43d58",
"assets/FontManifest.json": "6ad271a336fcae9ab1658ee874b90fd3",
"index.html": "63f7b00e3414d0c4860c9eb250449584",
"/": "63f7b00e3414d0c4860c9eb250449584",
"manifest.json": "9651912152c0445297b27aa20049e8aa",
"flutter_bootstrap.js": "a89cd0c890d30bcb0f1f7ada9834b3a8",
"main.dart.js": "03c65b911111e9b937e2c067829c2439",
"flutter.js": "24bc71911b75b5f8135c949e27a2984e",
"canvaskit/skwasm.js.symbols": "3a4aadf4e8141f284bd524976b1d6bdc",
"canvaskit/skwasm_heavy.wasm": "b0be7910760d205ea4e011458df6ee01",
"canvaskit/canvaskit.wasm": "9b6a7830bf26959b200594729d73538e",
"canvaskit/skwasm.js": "8060d46e9a4901ca9991edd3a26be4f0",
"canvaskit/skwasm_heavy.js": "740d43a6b8240ef9e23eed8c48840da4",
"canvaskit/skwasm.wasm": "7e5f3afdd3b0747a1fd4517cea239898",
"canvaskit/canvaskit.js": "8331fe38e66b3a898c4f37648aaf7ee2",
"canvaskit/canvaskit.js.symbols": "a3c9f77715b642d0437d9c275caba91e",
"canvaskit/skwasm_heavy.js.symbols": "0755b4fb399918388d71b59ad390b055",
"canvaskit/chromium/canvaskit.wasm": "a726e3f75a84fcdf495a15817c63a35d",
"canvaskit/chromium/canvaskit.js": "a80c765aaa8af8645c9fb1aae53f9abf",
"canvaskit/chromium/canvaskit.js.symbols": "e2d09f0e434bc118bf67dae526737d07",
"version.json": "57360474236f98b6438d00dfa27a5115",
"icons/Icon-maskable-512.png": "301a7604d45b3e739efc881eb04896ea",
"icons/Icon-maskable-192.png": "c457ef57daa1d16f64b27b786ec2ea3c",
"icons/Icon-192.png": "ac9a721a12bbc803b44f645561ecb1e1",
"icons/Icon-512.png": "96e752610906ba2a93c65f8abe1645f1"};
// The application shell files that are downloaded before a service worker can
// start.
const CORE = ["main.dart.js",
"index.html",
"flutter_bootstrap.js",
"assets/AssetManifest.bin.json",
"assets/FontManifest.json"];

// During install, the TEMP cache is populated with the application shell files.
self.addEventListener("install", (event) => {
  self.skipWaiting();
  return event.waitUntil(
    caches.open(TEMP).then((cache) => {
      return cache.addAll(
        CORE.map((value) => new Request(value, {'cache': 'reload'})));
    })
  );
});
// During activate, the cache is populated with the temp files downloaded in
// install. If this service worker is upgrading from one with a saved
// MANIFEST, then use this to retain unchanged resource files.
self.addEventListener("activate", function(event) {
  return event.waitUntil(async function() {
    try {
      var contentCache = await caches.open(CACHE_NAME);
      var tempCache = await caches.open(TEMP);
      var manifestCache = await caches.open(MANIFEST);
      var manifest = await manifestCache.match('manifest');
      // When there is no prior manifest, clear the entire cache.
      if (!manifest) {
        await caches.delete(CACHE_NAME);
        contentCache = await caches.open(CACHE_NAME);
        for (var request of await tempCache.keys()) {
          var response = await tempCache.match(request);
          await contentCache.put(request, response);
        }
        await caches.delete(TEMP);
        // Save the manifest to make future upgrades efficient.
        await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
        // Claim client to enable caching on first launch
        self.clients.claim();
        return;
      }
      var oldManifest = await manifest.json();
      var origin = self.location.origin;
      for (var request of await contentCache.keys()) {
        var key = request.url.substring(origin.length + 1);
        if (key == "") {
          key = "/";
        }
        // If a resource from the old manifest is not in the new cache, or if
        // the MD5 sum has changed, delete it. Otherwise the resource is left
        // in the cache and can be reused by the new service worker.
        if (!RESOURCES[key] || RESOURCES[key] != oldManifest[key]) {
          await contentCache.delete(request);
        }
      }
      // Populate the cache with the app shell TEMP files, potentially overwriting
      // cache files preserved above.
      for (var request of await tempCache.keys()) {
        var response = await tempCache.match(request);
        await contentCache.put(request, response);
      }
      await caches.delete(TEMP);
      // Save the manifest to make future upgrades efficient.
      await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
      // Claim client to enable caching on first launch
      self.clients.claim();
      return;
    } catch (err) {
      // On an unhandled exception the state of the cache cannot be guaranteed.
      console.error('Failed to upgrade service worker: ' + err);
      await caches.delete(CACHE_NAME);
      await caches.delete(TEMP);
      await caches.delete(MANIFEST);
    }
  }());
});
// The fetch handler redirects requests for RESOURCE files to the service
// worker cache.
self.addEventListener("fetch", (event) => {
  if (event.request.method !== 'GET') {
    return;
  }
  var origin = self.location.origin;
  var key = event.request.url.substring(origin.length + 1);
  // Redirect URLs to the index.html
  if (key.indexOf('?v=') != -1) {
    key = key.split('?v=')[0];
  }
  if (event.request.url == origin || event.request.url.startsWith(origin + '/#') || key == '') {
    key = '/';
  }
  // If the URL is not the RESOURCE list then return to signal that the
  // browser should take over.
  if (!RESOURCES[key]) {
    return;
  }
  // If the URL is the index.html, perform an online-first request.
  if (key == '/') {
    return onlineFirst(event);
  }
  event.respondWith(caches.open(CACHE_NAME)
    .then((cache) =>  {
      return cache.match(event.request).then((response) => {
        // Either respond with the cached resource, or perform a fetch and
        // lazily populate the cache only if the resource was successfully fetched.
        return response || fetch(event.request).then((response) => {
          if (response && Boolean(response.ok)) {
            cache.put(event.request, response.clone());
          }
          return response;
        });
      })
    })
  );
});
self.addEventListener('message', (event) => {
  // SkipWaiting can be used to immediately activate a waiting service worker.
  // This will also require a page refresh triggered by the main worker.
  if (event.data === 'skipWaiting') {
    self.skipWaiting();
    return;
  }
  if (event.data === 'downloadOffline') {
    downloadOffline();
    return;
  }
});
// Download offline will check the RESOURCES for all files not in the cache
// and populate them.
async function downloadOffline() {
  var resources = [];
  var contentCache = await caches.open(CACHE_NAME);
  var currentContent = {};
  for (var request of await contentCache.keys()) {
    var key = request.url.substring(origin.length + 1);
    if (key == "") {
      key = "/";
    }
    currentContent[key] = true;
  }
  for (var resourceKey of Object.keys(RESOURCES)) {
    if (!currentContent[resourceKey]) {
      resources.push(resourceKey);
    }
  }
  return contentCache.addAll(resources);
}
// Attempt to download the resource online before falling back to
// the offline cache.
function onlineFirst(event) {
  return event.respondWith(
    fetch(event.request).then((response) => {
      return caches.open(CACHE_NAME).then((cache) => {
        cache.put(event.request, response.clone());
        return response;
      });
    }).catch((error) => {
      return caches.open(CACHE_NAME).then((cache) => {
        return cache.match(event.request).then((response) => {
          if (response != null) {
            return response;
          }
          throw error;
        });
      });
    })
  );
}
