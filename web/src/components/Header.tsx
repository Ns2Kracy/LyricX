import { Link } from "@tanstack/solid-router";

export default function Header() {
  return (
    <header class="sticky top-0 z-50 border-b border-black/10 bg-[#f7f7f2]/85 backdrop-blur-xl">
      <nav class="mx-auto flex h-16 max-w-7xl items-center gap-4 px-4 sm:px-6 lg:px-8">
        <Link to="/" class="flex min-w-0 items-center gap-3 text-neutral-950 no-underline">
          <span class="flex size-8 shrink-0 items-center justify-center rounded-lg bg-neutral-950 text-[13px] font-semibold text-white">
            LX
          </span>
          <span class="text-base font-semibold">LyricX</span>
        </Link>

        <div class="ml-auto flex min-w-0 items-center gap-2 overflow-x-auto text-sm font-medium text-neutral-600 sm:gap-5">
          <a href="/#features" class="shrink-0 rounded-full px-2 py-1 no-underline hover:text-neutral-950">
            Features
          </a>
          <a href="/#workflow" class="shrink-0 rounded-full px-2 py-1 no-underline hover:text-neutral-950">
            Workflow
          </a>
          <Link to="/about" class="shrink-0 rounded-full px-2 py-1 no-underline hover:text-neutral-950">
            About
          </Link>
          <a
            href="https://github.com/Ns2Kracy/LyricX/releases"
            target="_blank"
            rel="noreferrer"
            class="shrink-0 rounded-full bg-neutral-950 px-4 py-2 text-white no-underline transition hover:bg-neutral-800 active:translate-y-px"
          >
            Download
          </a>
        </div>
      </nav>
    </header>
  );
}
