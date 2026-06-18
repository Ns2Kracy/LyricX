import { createFileRoute } from "@tanstack/solid-router";

export const Route = createFileRoute("/about")({
  component: About,
});

const requirements = ["macOS 14 or newer", "Spotify for macOS", "Internet access for lyric lookup"];

function About() {
  return (
    <main class="min-h-[100dvh] px-4 py-16 text-neutral-950 sm:px-6 lg:px-8">
      <section class="mx-auto max-w-5xl">
        <p class="mb-4 text-sm font-semibold text-[#167a3d]">About LyricX</p>
        <h1 class="max-w-4xl text-4xl font-semibold leading-tight sm:text-6xl">
          A small macOS utility for people who read along while Spotify plays.
        </h1>
        <p class="mt-6 max-w-3xl text-lg leading-8 text-neutral-600">
          LyricX is built around one job: show the current synced lyric line without adding another floating app window to manage.
        </p>
      </section>

      <section class="mx-auto mt-12 grid max-w-5xl gap-4 lg:grid-cols-[1.1fr_0.9fr]">
        <article class="rounded-lg border border-black/10 bg-white/65 p-6 shadow-sm">
          <h2 class="text-2xl font-semibold">Why it exists</h2>
          <p class="mt-4 text-base leading-7 text-neutral-600">
            Desktop lyric overlays are useful, but they can be noisy. LyricX takes the smaller route: menu-bar text for the current line, simple controls, and local polling of Spotify playback state.
          </p>
          <p class="mt-4 text-base leading-7 text-neutral-600">
            When lyrics are not available, the app keeps the experience readable by showing track information or a clear missing-lyrics state.
          </p>
        </article>

        <article class="rounded-lg border border-black/10 bg-[#fbfbf8] p-6 shadow-sm">
          <h2 class="text-2xl font-semibold">Requirements</h2>
          <ul class="mt-5 space-y-3 text-base text-neutral-600">
            {requirements.map((item) => (
              <li class="flex gap-3">
                <span class="mt-2 size-2 shrink-0 rounded-full bg-[#1db954]" aria-hidden="true" />
                <span>{item}</span>
              </li>
            ))}
          </ul>
        </article>
      </section>
    </main>
  );
}
