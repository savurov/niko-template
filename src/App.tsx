import { useState } from "react";

function App() {
  const [count, setCount] = useState(0);

  return (
    <main className="grid min-h-screen place-items-center bg-gradient-to-br from-zinc-950 via-slate-900 to-zinc-900 px-6 text-slate-100">
      <div className="w-full max-w-sm rounded-2xl border border-white/10 bg-white/5 p-6 shadow-2xl shadow-black/40 backdrop-blur">
        <p className="mt-3 text-5xl font-semibold tabular-nums">{count}</p>
        <div className="mt-6 flex gap-3">
          <button
            onClick={() => setCount((v) => v + 1)}
            className="flex-1 rounded-xl bg-cyan-400 px-4 py-2 font-medium text-zinc-950 transition hover:bg-cyan-300"
          >
            Click me
          </button>
          <button
            onClick={() => setCount(0)}
            className="rounded-xl border border-white/15 px-4 py-2 text-slate-200 transition hover:bg-white/10"
          >
            Reset
          </button>
        </div>
      </div>
    </main>
  );
}

export default App
