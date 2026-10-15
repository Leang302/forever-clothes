// Form validation with zod. Forms use `noValidate` (no browser popups) and show these messages inline instead.
import { z } from "zod";

/**
 * Validates `values` against `schema`.
 * Returns { data, errors }: `data` is the parsed result (null when invalid) and `errors` maps each field
 * (dot path for nested fields, e.g. "address.city") to its first message.
 */
export function validate(schema, values) {
  const result = schema.safeParse(values);
  if (result.success) return { data: result.data, errors: {} };
  const errors = {};
  result.error.issues.forEach((issue) => {
    const key = issue.path.join('.') || '_form';
    if (!(key in errors)) errors[key] = issue.message;
  });
  return { data: null, errors };
}

// Reusable field rules.
export const text = (label, max) =>
  z.string().trim().min(1, `${label} is required`).max(max, `${label} must be ${max} characters or fewer`);

export const email = z.string().trim().min(1, 'Email is required').email('Enter a valid email address');

export const password = z
  .string()
  .min(8, 'Password must be at least 8 characters')
  .max(72, 'Password must be 72 characters or fewer');

// A number typed into a text/number input ("" = missing).
export const numberField = (label) =>
  z
    .union([z.string(), z.number()])
    .refine((v) => String(v).trim() !== '', `${label} is required`)
    .transform((v) => Number(v))
    .refine((v) => Number.isFinite(v), `${label} must be a number`);

// Category and sub-category names, same rules as the API.
export const NAME_MAX = 40;
export const categoryName = z
  .string()
  .transform((v) => v.trim().replace(/\s+/g, ' '))
  .pipe(
    z
      .string()
      .min(1, 'Enter a name')
      .max(NAME_MAX, `Use ${NAME_MAX} characters or fewer`)
      .regex(/^[\p{L}\p{N}][\p{L}\p{N} &'-]*$/u, "Use letters, numbers, spaces, & ' or - (start with a letter or number)"),
  );

export { z };
