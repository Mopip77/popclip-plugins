// Fancy Text Converter for PopClip
// Converts regular text to fancy Unicode mathematical alphanumeric symbols

// Style mapping with Unicode offsets
const styleMap = {
  'sans-serif-bold-italic': {
    upperStart: 0x1D63C,  // 𝘼
    lowerStart: 0x1D656,  // 𝙖
    digitStart: 0x1D7EC   // 𝟬
  },
  'bold-script': {
    upperStart: 0x1D4D0,  // 𝓐
    lowerStart: 0x1D4EA,  // 𝓪
    digitStart: 0x1D7EC   // 𝟬 (bold digits)
  },
  'script': {
    // Script style has some missing characters, need special handling
    upper: {
      A: 0x1D49C, B: 0x212C, C: 0x1D49E, D: 0x1D49F, E: 0x2130, F: 0x2131,
      G: 0x1D4A2, H: 0x210B, I: 0x2110, J: 0x1D4A5, K: 0x1D4A6, L: 0x2112,
      M: 0x2133, N: 0x1D4A9, O: 0x1D4AA, P: 0x1D4AB, Q: 0x1D4AC, R: 0x211B,
      S: 0x1D4AE, T: 0x1D4AF, U: 0x1D4B0, V: 0x1D4B1, W: 0x1D4B2, X: 0x1D4B3,
      Y: 0x1D4B4, Z: 0x1D4B5
    },
    lower: {
      a: 0x1D4B6, b: 0x1D4B7, c: 0x1D4B8, d: 0x1D4B9, e: 0x212F, f: 0x1D4BB,
      g: 0x210A, h: 0x1D4BD, i: 0x1D4BE, j: 0x1D4BF, k: 0x1D4C0, l: 0x1D4C1,
      m: 0x1D4C2, n: 0x1D4C3, o: 0x2134, p: 0x1D4C5, q: 0x1D4C6, r: 0x1D4C7,
      s: 0x1D4C8, t: 0x1D4C9, u: 0x1D4CA, v: 0x1D4CB, w: 0x1D4CC, x: 0x1D4CD,
      y: 0x1D4CE, z: 0x1D4CF
    },
    digitStart: 0x1D7CE   // 𝟎 (regular digits)
  },
  'sans-serif-bold': {
    upperStart: 0x1D5D4,  // 𝗔
    lowerStart: 0x1D5EE,  // 𝗮
    digitStart: 0x1D7EC   // 𝟬
  },
  'bold': {
    upperStart: 0x1D400,  // 𝐀
    lowerStart: 0x1D41A,  // 𝐚
    digitStart: 0x1D7CE   // 𝟎
  },
  'italic': {
    upperStart: 0x1D434,  // 𝐴
    lowerStart: 0x1D44E,  // 𝑎
    digitStart: 0x1D7CE   // 𝟎 (regular digits)
  },
  'bold-italic': {
    upperStart: 0x1D468,  // 𝑨
    lowerStart: 0x1D482,  // 𝒂
    digitStart: 0x1D7CE   // 𝟎 (regular digits)
  },
  'double-struck': {
    // Double-struck also has missing characters
    upper: {
      A: 0x1D538, B: 0x1D539, C: 0x2102, D: 0x1D53B, E: 0x1D53C, F: 0x1D53D,
      G: 0x1D53E, H: 0x210D, I: 0x1D540, J: 0x1D541, K: 0x1D542, L: 0x1D543,
      M: 0x1D544, N: 0x2115, O: 0x1D546, P: 0x2119, Q: 0x211A, R: 0x211D,
      S: 0x1D54A, T: 0x1D54B, U: 0x1D54C, V: 0x1D54D, W: 0x1D54E, X: 0x1D54F,
      Y: 0x1D550, Z: 0x2124
    },
    lowerStart: 0x1D552,  // 𝕒
    digitStart: 0x1D7D8   // 𝟘
  },
  'monospace': {
    upperStart: 0x1D670,  // 𝙰
    lowerStart: 0x1D68A,  // 𝚊
    digitStart: 0x1D7F6   // 𝟶
  }
};

/**
 * Convert a character to fancy Unicode style
 */
function convertChar(char, style) {
  const code = char.charCodeAt(0);
  const offsets = styleMap[style];

  if (!offsets) {
    return char; // Unknown style, return original
  }

  // Handle uppercase letters A-Z (65-90)
  if (code >= 65 && code <= 90) {
    if (offsets.upper) {
      // Special mapping (script, double-struck)
      const mapped = offsets.upper[char];
      return mapped ? String.fromCodePoint(mapped) : char;
    } else if (offsets.upperStart) {
      // Linear offset mapping
      return String.fromCodePoint(offsets.upperStart + (code - 65));
    }
  }

  // Handle lowercase letters a-z (97-122)
  if (code >= 97 && code <= 122) {
    if (offsets.lower) {
      // Special mapping (script)
      const mapped = offsets.lower[char];
      return mapped ? String.fromCodePoint(mapped) : char;
    } else if (offsets.lowerStart) {
      // Linear offset mapping
      return String.fromCodePoint(offsets.lowerStart + (code - 97));
    }
  }

  // Handle digits 0-9 (48-57)
  if (code >= 48 && code <= 57) {
    if (offsets.digitStart) {
      return String.fromCodePoint(offsets.digitStart + (code - 48));
    }
  }

  // Keep all other characters unchanged (spaces, punctuation, symbols)
  return char;
}

/**
 * Convert entire text to fancy style
 */
function convertToFancy(text, style) {
  return text.split('').map(char => convertChar(char, style)).join('');
}

// Main execution
const style = popclip.options.style || 'sans-serif-bold-italic';
const inputText = popclip.input.text;
const convertedText = convertToFancy(inputText, style);

// Replace selected text with converted text
popclip.pasteText(convertedText);
