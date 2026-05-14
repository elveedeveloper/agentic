import { describe, expect, it } from 'vitest';
import { farewell } from '../src/farewell.js';

describe('farewell', () => {
  it('returns a goodbye message for a non-empty name', () => {
    expect(farewell('World')).toBe('Goodbye, World!');
  });

  it('handles a different name', () => {
    expect(farewell('Salman')).toBe('Goodbye, Salman!');
  });

  it('returns a bare goodbye for an empty name', () => {
    expect(farewell('')).toBe('Goodbye!');
  });

  it('preserves whitespace in non-empty names', () => {
    expect(farewell('  ')).toBe('Goodbye,   !');
  });
});
