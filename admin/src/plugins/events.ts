// @ts-nocheck
import em from 'tiny-emitter/instance'
import type {TinyEmitter}
from 'tiny-emitter'

// will maybe use this in the future and don't want to research this again
// so this code stays here.
const emitter = em as TinyEmitter

export default {
    $on: (...args : any) => emitter.on(...args),
    $once: (...args : any) => emitter.once(...args),
    $off: (...args : any) => emitter.off(...args),
    $emit: (...args : any) => emitter.emit(...args)
}
