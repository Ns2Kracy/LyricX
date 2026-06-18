import "./styles.css";

const app = document.querySelector<HTMLDivElement>("#app");

if (app) {
  app.innerHTML = `
    <header class="sticky top-0 z-50 border-b border-black/10 bg-[#f7f7f2]/85 backdrop-blur-xl">
      <nav class="mx-auto flex h-16 max-w-7xl items-center gap-4 px-4 sm:px-6 lg:px-8">
        <a href="#top" class="flex min-w-0 items-center gap-3 text-neutral-950 no-underline">
          <span class="flex size-8 shrink-0 items-center justify-center rounded-lg bg-neutral-950 text-[13px] font-semibold text-white">LX</span>
          <span class="text-base font-semibold">LyricX</span>
        </a>
        <div class="ml-auto flex min-w-0 items-center gap-2 overflow-x-auto text-sm font-medium text-neutral-600 sm:gap-5">
          <a href="#features" class="shrink-0 rounded-full px-2 py-1 no-underline hover:text-neutral-950">Features</a>
          <a href="#workflow" class="shrink-0 rounded-full px-2 py-1 no-underline hover:text-neutral-950">Workflow</a>
          <a href="#download" class="shrink-0 rounded-full bg-neutral-950 px-4 py-2 text-white no-underline transition hover:bg-neutral-800 active:translate-y-px">Download</a>
        </div>
      </nav>
    </header>

    <main id="top" class="min-h-[100dvh] text-neutral-950">
      <section class="mx-auto grid max-w-7xl gap-12 px-4 pb-16 pt-16 sm:px-6 sm:pb-20 sm:pt-20 lg:min-h-[calc(100dvh-4rem)] lg:grid-cols-[1fr_0.92fr] lg:items-center lg:px-8 lg:pt-14">
        <div class="max-w-3xl">
          <p class="mb-5 inline-flex rounded-full border border-black/10 bg-white/70 px-3 py-1 text-sm font-medium text-neutral-700 shadow-sm">
            Native macOS menu-bar lyrics for Spotify
          </p>
          <h1 class="max-w-4xl text-5xl font-semibold leading-[1.02] text-neutral-950 sm:text-6xl lg:text-7xl">
            Spotify lyrics, right where your eyes already are.
          </h1>
          <p class="mt-6 max-w-2xl text-lg leading-8 text-neutral-600 sm:text-xl">
            LyricX follows the current Spotify track, finds synced LRCLIB lyrics, and keeps the active line in your macOS menu bar.
          </p>
          <div class="mt-8 flex flex-col gap-3 sm:flex-row">
            <a href="https://github.com/Ns2Kracy/LyricX/releases" class="inline-flex h-12 items-center justify-center rounded-full bg-neutral-950 px-6 text-sm font-semibold text-white no-underline transition hover:bg-neutral-800 active:translate-y-px" target="_blank" rel="noreferrer">
              Download latest
            </a>
            <a href="#download" class="inline-flex h-12 items-center justify-center rounded-full border border-black/15 bg-white/70 px-6 text-sm font-semibold text-neutral-950 no-underline transition hover:bg-white active:translate-y-px">
              Build from source
            </a>
          </div>
          <div class="mt-10 grid max-w-2xl grid-cols-1 gap-3 text-sm text-neutral-600 sm:grid-cols-3">
            <div class="border-l border-black/15 pl-4"><strong class="block text-neutral-950">macOS 14+</strong>SwiftUI menu-bar app</div>
            <div class="border-l border-black/15 pl-4"><strong class="block text-neutral-950">Spotify desktop</strong>Local playback polling</div>
            <div class="border-l border-black/15 pl-4"><strong class="block text-neutral-950">No account flow</strong>No Spotify OAuth in v1</div>
          </div>
        </div>

        <div class="relative mx-auto w-full max-w-[560px]" aria-label="LyricX menu bar preview" role="img">
          <div class="relative rounded-lg border border-black/10 bg-[#d9d9d2] p-3 shadow-[0_30px_90px_rgba(10,10,10,0.16)]">
            <div class="rounded-lg border border-black/10 bg-neutral-950 p-4 text-white">
              <div class="flex h-9 items-center gap-4 border-b border-white/10 text-xs text-neutral-400">
                <span class="font-semibold text-white">LyricX</span>
                <span>Spotify</span>
                <span class="ml-auto rounded-full bg-[#1db954]/15 px-2 py-1 text-[#53dc7d]">Playing</span>
              </div>
              <div class="py-8">
                <div class="mb-5 rounded-lg border border-white/10 bg-white/[0.04] p-4">
                  <p class="text-sm text-neutral-400">Current track</p>
                  <p class="mt-1 text-lg font-semibold">A song worth keeping close</p>
                </div>
                <div class="overflow-hidden rounded-lg border border-white/10 bg-black p-5">
                  <div class="lyric-track whitespace-nowrap text-2xl font-semibold text-white">
                    Synced lyrics move with the music, line by line
                  </div>
                  <p class="mt-3 text-sm text-neutral-500">Next line is ready before you need it</p>
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      <section id="features" class="border-y border-black/10 bg-white/55 px-4 py-16 sm:px-6 lg:px-8">
        <div class="mx-auto max-w-7xl">
          <div class="max-w-2xl">
            <p class="mb-3 text-sm font-semibold text-[#167a3d]">What makes it useful</p>
            <h2 class="text-3xl font-semibold leading-tight text-neutral-950 sm:text-5xl">A tiny surface for a very specific habit.</h2>
            <p class="mt-5 text-base leading-7 text-neutral-600">The app is intentionally narrow: keep lyrics visible, avoid extra login work, and stay out of the way when lyrics are missing.</p>
          </div>
          <div class="mt-10 grid gap-4 lg:grid-cols-6">
            <article class="rounded-lg border border-black/10 bg-[#fbfbf8] p-6 shadow-sm lg:col-span-3">
              <h3 class="text-xl font-semibold text-neutral-950">Lives in the menu bar</h3>
              <p class="mt-3 max-w-2xl text-base leading-7 text-neutral-600">The active lyric line sits where your eyes already glance, without taking over the desktop.</p>
            </article>
            <article class="rounded-lg border border-black/10 bg-[#fbfbf8] p-6 shadow-sm lg:col-span-3">
              <h3 class="text-xl font-semibold text-neutral-950">Built for Spotify desktop</h3>
              <p class="mt-3 max-w-2xl text-base leading-7 text-neutral-600">LyricX reads local playback state through AppleScript, so the first version avoids OAuth setup.</p>
            </article>
            <article class="rounded-lg border border-black/10 bg-[#fbfbf8] p-6 shadow-sm lg:col-span-2">
              <h3 class="text-xl font-semibold text-neutral-950">Synced by LRCLIB</h3>
              <p class="mt-3 max-w-2xl text-base leading-7 text-neutral-600">Timed LRC lyrics are fetched, parsed, cached locally, and matched to the current playback position.</p>
            </article>
            <article class="rounded-lg border border-black/10 bg-[#fbfbf8] p-6 shadow-sm lg:col-span-2">
              <h3 class="text-xl font-semibold text-neutral-950">Graceful fallbacks</h3>
              <p class="mt-3 max-w-2xl text-base leading-7 text-neutral-600">When synced lyrics are missing, the app keeps polling Spotify and can show the current track instead.</p>
            </article>
            <article class="rounded-lg border border-black/10 bg-[#fbfbf8] p-6 shadow-sm lg:col-span-2">
              <h3 class="text-xl font-semibold text-neutral-950">Small by design</h3>
              <p class="mt-3 max-w-2xl text-base leading-7 text-neutral-600">A native SwiftUI menu-bar app with focused controls for visibility, refresh, and quit.</p>
            </article>
          </div>
        </div>
      </section>

      <section id="workflow" class="mx-auto max-w-7xl px-4 py-16 sm:px-6 lg:px-8">
        <div class="grid gap-10 lg:grid-cols-[0.9fr_1.1fr] lg:items-start">
          <div>
            <p class="mb-3 text-sm font-semibold text-[#167a3d]">How it behaves</p>
            <h2 class="text-3xl font-semibold leading-tight text-neutral-950 sm:text-5xl">Local first, quiet when the network is not.</h2>
          </div>
          <div class="grid gap-4">
            <article class="rounded-lg border border-black/10 bg-white/65 p-6 shadow-sm"><h3 class="text-lg font-semibold text-neutral-950">Spotify plays</h3><p class="mt-2 text-base leading-7 text-neutral-600">The local desktop app exposes track, artist, duration, state, and playback position.</p></article>
            <article class="rounded-lg border border-black/10 bg-white/65 p-6 shadow-sm"><h3 class="text-lg font-semibold text-neutral-950">Lyrics match</h3><p class="mt-2 text-base leading-7 text-neutral-600">LyricX looks up synced lyrics, caches the LRC, and keeps misses non-fatal.</p></article>
            <article class="rounded-lg border border-black/10 bg-white/65 p-6 shadow-sm"><h3 class="text-lg font-semibold text-neutral-950">The line updates</h3><p class="mt-2 text-base leading-7 text-neutral-600">The current lyric moves through the menu bar with stable width and readable contrast.</p></article>
          </div>
        </div>
      </section>

      <section id="download" class="bg-neutral-950 px-4 py-16 text-white sm:px-6 lg:px-8">
        <div class="mx-auto grid max-w-7xl gap-8 lg:grid-cols-[1fr_0.85fr] lg:items-center">
          <div>
            <p class="mb-3 text-sm font-semibold text-[#3fd36f]">Get LyricX</p>
            <h2 class="text-3xl font-semibold leading-tight sm:text-5xl">Download a release or build it locally.</h2>
            <p class="mt-5 max-w-2xl text-base leading-7 text-neutral-300">LyricX is unsigned today. macOS may ask you to approve Automation access for Spotify the first time it reads playback state.</p>
            <div class="mt-8 flex flex-col gap-3 sm:flex-row">
              <a href="https://github.com/Ns2Kracy/LyricX/releases" class="inline-flex h-12 items-center justify-center rounded-full bg-white px-6 text-sm font-semibold text-neutral-950 no-underline transition hover:bg-neutral-200 active:translate-y-px" target="_blank" rel="noreferrer">Open releases</a>
              <a href="https://github.com/Ns2Kracy/LyricX" class="inline-flex h-12 items-center justify-center rounded-full border border-white/20 px-6 text-sm font-semibold text-white no-underline transition hover:bg-white/10 active:translate-y-px" target="_blank" rel="noreferrer">View source</a>
            </div>
          </div>
          <pre class="overflow-x-auto rounded-lg border border-white/15 bg-black/40 p-5 text-sm leading-7 text-neutral-200 shadow-2xl"><code>swift build
swift run LyricXUnitTests
bash scripts/build-app.sh
open dist/LyricX.app</code></pre>
        </div>
      </section>
    </main>
  `;
}
