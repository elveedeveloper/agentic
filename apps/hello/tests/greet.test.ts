import { describe, expect, it } from 'vitest';
import { greet } from '../src/greet.js';

describe('greet', () => {
  it('returns a hello message for the given name', () => {
    expect(greet('World')).toBe('Hello, World!');
  });
});
