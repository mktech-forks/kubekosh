import { useState, useRef, useEffect, useMemo } from 'react'
import styles from './Catalog.module.css'

// Full-screen, searchable catalog for browsing the whole curriculum: a grid of
// subject cards, each listing its bundles. Click a subject to enter it, or a
// bundle to jump straight there. Search filters subjects and bundles live.
export default function Catalog({ subjects, allBundles = [], activeSubjectId, onNavigate, onClose }) {
  const [query, setQuery] = useState('')
  const searchRef = useRef(null)

  useEffect(() => { searchRef.current?.focus() }, [])
  useEffect(() => {
    const onKey = (e) => { if (e.key === 'Escape') onClose() }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [onClose])

  const q = query.trim().toLowerCase()
  const match = (txt) => (txt || '').toLowerCase().includes(q)

  const cards = useMemo(() => {
    return subjects.map(s => {
      const subjBundles = allBundles.filter(b => b.subject === s.id)
      if (!q) return { s, bundles: subjBundles }
      if (match(s.name) || match(s.tagline)) return { s, bundles: subjBundles }
      const hits = subjBundles.filter(b => match(b.name) || match(b.tagline))
      return hits.length ? { s, bundles: hits } : null
    }).filter(Boolean)
  }, [q, subjects, allBundles])

  const totalBundles = allBundles.length

  return (
    <div className={styles.overlay} onMouseDown={(e) => { if (e.target === e.currentTarget) onClose() }}>
      <div className={styles.panel}>
        <div className={styles.header}>
          <div className={styles.titleRow}>
            <h2 className={styles.title}>Browse the Catalog</h2>
            <span className={styles.summary}>{subjects.length} subjects · {totalBundles} bundles</span>
            <button className={styles.closeBtn} onClick={onClose} aria-label="Close catalog">×</button>
          </div>
          <div className={styles.searchBox}>
            <span className={styles.searchIcon} aria-hidden="true">
              <svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round">
                <circle cx="11" cy="11" r="7" /><line x1="21" y1="21" x2="16.65" y2="16.65" />
              </svg>
            </span>
            <input
              ref={searchRef}
              className={styles.searchInput}
              type="text"
              placeholder="Search subjects and bundles…"
              value={query}
              onChange={e => setQuery(e.target.value)}
            />
            {query && <button className={styles.searchClear} onClick={() => { setQuery(''); searchRef.current?.focus() }} aria-label="Clear">×</button>}
          </div>
        </div>

        <div className={styles.grid}>
          {cards.length === 0 && (
            <div className={styles.empty}>No subjects or bundles match “{query}”.</div>
          )}
          {cards.map(({ s, bundles }) => {
            const total = s.stats?.total || 0
            const done = s.stats?.completed || 0
            const pct = total > 0 ? Math.round((done / total) * 100) : 0
            return (
              <div key={s.id} className={`${styles.card} ${s.id === activeSubjectId ? styles.cardActive : ''}`} style={{ '--bcolor': s.color, '--bdim': s.colorDim }}>
                <button className={styles.cardHead} onClick={() => onNavigate(s.id)} title={`Open ${s.name}`}>
                  <span className={styles.cardIcon}>{s.icon}</span>
                  <span className={styles.cardHeadText}>
                    <span className={styles.cardName}>{s.name}</span>
                    <span className={styles.cardTagline}>{s.tagline}</span>
                  </span>
                </button>

                <div className={styles.cardStats}>
                  <div className={styles.progressTrack}><div className={styles.progressFill} style={{ width: `${pct}%` }} /></div>
                  <span className={styles.cardMeta}>{done}/{total} · {bundles.length} bundle{bundles.length === 1 ? '' : 's'}</span>
                </div>

                <div className={styles.bundleList}>
                  {bundles.map(b => {
                    const bt = b.stats?.total || 0
                    const bd = b.stats?.completed || 0
                    return (
                      <button key={b.id} className={styles.bundleRow} onClick={() => onNavigate(s.id, b.id)} title={b.tagline}>
                        <span className={styles.bundleName}>{b.name}</span>
                        {bt > 0 && <span className={styles.bundleMeta}>{bd}/{bt}</span>}
                      </button>
                    )
                  })}
                </div>
              </div>
            )
          })}
        </div>
      </div>
    </div>
  )
}
