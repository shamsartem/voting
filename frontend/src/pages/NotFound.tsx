import { Link } from "react-router-dom";

export function NotFound() {
  return (
    <div>
      <h2>Page not found!</h2>
      <p>
        <Link to="/">Go to the home page</Link>
      </p>
    </div>
  );
}
