// This code includes portions of the GPL v3 licensed code from the V playground, available at https://github.com/vlang/playground.

const baseAttributes = [
    "params", "noinit", "required", "skip", "assert_continues",
    "unsafe", "manualfree", "heap", "nonnull", "primary", "inline",
    "direct_array_access", "live", "flag", "noinline", "noreturn", "typedef", "console",
    "sql", "table", "deprecated", "deprecated_after", "export", "callconv"
]

const word = "[\\w_]+"
// [noinit]
export const simpleAttributesRegexp = new RegExp(`^(${baseAttributes.join("|")})]$`)

// [key: value]
const keyValue = `(${word}: ${word})`
export const singleKeyValueAttributesRegexp = new RegExp(`^${keyValue}]$`)

// [attr1; attr2]
export const severalSingleKeyValueAttributesRegexp = new RegExp(`^(${baseAttributes.join("|")}(; ?)?){2,}]$`)

// [key: value; key: value]
export const keyValueAttributesRegexp = new RegExp(`^((${keyValue})(; )?){2,}]$`)

// [if expr ?]
export const ifAttributesRegexp = new RegExp(`^if ${word} \\??]`)