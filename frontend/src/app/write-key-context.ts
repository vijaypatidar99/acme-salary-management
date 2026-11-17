import { createContext, useContext } from 'react'
export interface WriteAccess {
  writeKey: string
  setWriteKey: (key: string) => void
  writesDisabled: boolean
  disableWrites: () => void
}
export const WriteKeyContext = createContext<WriteAccess | null>(null)
export function useWriteAccess() {
  const context = useContext(WriteKeyContext)
  if (!context) throw new Error('Write access provider is missing')
  return context
}
