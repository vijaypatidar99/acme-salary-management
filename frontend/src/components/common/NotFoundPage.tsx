import { Link } from 'react-router-dom'

export default function NotFoundPage() {
  return (
    <section>
      <h1 className="text-2xl font-semibold">Page not found</h1>
      <p className="mt-2">
        <Link to="/" className="text-blue-700 underline">
          Back to the home page
        </Link>
      </p>
    </section>
  )
}
