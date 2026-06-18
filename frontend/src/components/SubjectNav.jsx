import styles from './SubjectNav.module.css'

// Slim context bar: shows the active subject and a button that opens the
// full searchable Catalog for browsing/discovering subjects and bundles.
// (The old horizontal pill list didn't scale for discovery.)
export default function SubjectNav({ subjects, activeSubjectId, examSession, onBrowse }) {
  if (!subjects || subjects.length === 0) return null
  const s = subjects.find(x => x.id === activeSubjectId) || null
  const total = s?.stats?.total || 0
  const completed = s?.stats?.completed || 0

  return (
    <nav className={styles.nav} aria-label="Subject">
      <button
        className={styles.browseBtn}
        onClick={onBrowse}
        disabled={!!examSession}
        title={examSession ? 'Submit or abandon the current exam to switch subjects' : 'Browse all subjects and bundles'}
      >
        <svg viewBox="0 0 24 24" width="15" height="15" fill="none" stroke="currentColor" strokeWidth="2.1" strokeLinecap="round" strokeLinejoin="round">
          <rect x="3" y="3" width="7" height="7" rx="1.5" /><rect x="14" y="3" width="7" height="7" rx="1.5" />
          <rect x="3" y="14" width="7" height="7" rx="1.5" /><rect x="14" y="14" width="7" height="7" rx="1.5" />
        </svg>
        Browse subjects
      </button>

      {s && (
        <div className={styles.current} style={{ '--bcolor': s.color, '--bdim': s.colorDim }}>
          <span className={styles.icon}>{s.icon}</span>
          <div className={styles.text}>
            <span className={styles.name}>{s.name}</span>
            <span className={styles.tagline}>{s.tagline}</span>
          </div>
          {!examSession && total > 0 && <span className={styles.count}>{completed}/{total}</span>}
        </div>
      )}

      {examSession && <span className={styles.examNote}>Exam in progress — subject locked</span>}
    </nav>
  )
}
