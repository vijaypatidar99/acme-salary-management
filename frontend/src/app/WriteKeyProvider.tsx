import { useState, type ReactNode } from 'react'
import { WriteKeyContext } from './write-key-context'

export default function WriteKeyProvider({ children }: { children: ReactNode }) {
  const [writeKey, setWriteKey] = useState('')
  const [writesDisabled, setWritesDisabled] = useState(false)
  return <WriteKeyContext.Provider value={{ writeKey, setWriteKey, writesDisabled, disableWrites: () => { setWritesDisabled(true); setWriteKey('') } }}>{children}</WriteKeyContext.Provider>
}
