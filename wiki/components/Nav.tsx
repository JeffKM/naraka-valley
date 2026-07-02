"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { Images, ListChecks } from "lucide-react";

const LINKS = [
  { href: "/", label: "에셋 갤러리", icon: Images },
  { href: "/mechanics", label: "메카닉 현황", icon: ListChecks },
];

export default function Nav() {
  const path = usePathname();
  return (
    <nav className="sticky top-0 z-10 border-b border-[var(--edge)] bg-[var(--bg)]/90 backdrop-blur">
      <div className="mx-auto flex max-w-[1400px] items-center gap-1 px-5 py-2.5">
        <span className="mr-3 text-sm font-bold tracking-tight text-[var(--amber)]">나라카 밸리 위키</span>
        {LINKS.map(({ href, label, icon: Icon }) => {
          const active = href === "/" ? path === "/" : path.startsWith(href);
          return (
            <Link
              key={href}
              href={href}
              className={`flex items-center gap-1.5 rounded-md px-3 py-1.5 text-sm transition ${
                active
                  ? "bg-[var(--amber)]/15 text-[var(--amber)]"
                  : "text-[var(--muted)] hover:text-[var(--ink)]"
              }`}
            >
              <Icon className="size-4" />
              {label}
            </Link>
          );
        })}
      </div>
    </nav>
  );
}
