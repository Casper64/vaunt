import type { BlockAPI } from '@editorjs/editorjs'
import { EditorState } from "@codemirror/state";
import { EditorView, keymap, highlightActiveLine, lineNumbers, highlightActiveLineGutter } from "@codemirror/view";
import { defaultKeymap, history, historyKeymap } from "@codemirror/commands";
import { indentOnInput, bracketMatching, syntaxHighlighting, defaultHighlightStyle, indentUnit } from "@codemirror/language";
import { indentWithTab } from "@codemirror/commands"
import { languages } from "@codemirror/language-data";
import {StreamLanguage} from "@codemirror/language"
import { createMode } from './v/v'

import { oneDark } from "@codemirror/theme-one-dark";

//@ts-ignore
import NiceSelect from "nice-select2/dist/js/nice-select2"
import "nice-select2/dist/css/nice-select2.css";
import "@/plugins/tools/code.scss"

interface CodeBlockData {
    language: string
    code: string
    html: string
}

const defaultCode = '// put your code here' + '\n'.repeat(4)

//@ts-ignore
const vlang = StreamLanguage.define(createMode())

export default class CodeBlock {
    data: CodeBlockData
    api: BlockAPI

    // codemirror
    //@ts-ignore
    codemirrorState: EditorState
    //@ts-ignore
    codemirrorView: EditorView

    // elements
    //@ts-ignore
    _wrapper: HTMLDivElement;

    constructor({ data, api }: any) {
        this.data = data
        this.api = api

        // set default values when creating a new block
        if (this.data.code == undefined) {
            this.data.code = defaultCode
        }
        if (this.data.language == undefined) {
            this.data.language = 'V'
        }
    }

    // toolbox display
    static get toolbox() {
        return {
            title: 'Code',
            icon: '<svg fill="#000000" width="800px" height="800px" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path d="M1.293,11.293l4-4A1,1,0,1,1,6.707,8.707L3.414,12l3.293,3.293a1,1,0,1,1-1.414,1.414l-4-4A1,1,0,0,1,1.293,11.293Zm17.414-4a1,1,0,1,0-1.414,1.414L20.586,12l-3.293,3.293a1,1,0,1,0,1.414,1.414l4-4a1,1,0,0,0,0-1.414ZM13.039,4.726l-4,14a1,1,0,0,0,.686,1.236A1.053,1.053,0,0,0,10,20a1,1,0,0,0,.961-.726l4-14a1,1,0,1,0-1.922-.548Z"/></svg>'
        }
    }

    onPaste() {
        // on paste is already handled by codemirror
        return
    }

    render() {
        const wrapper = document.createElement('div');
        wrapper.classList.add('code-editor')

        // stop editorjs from hijacking codemirrors shortcuts
        wrapper.addEventListener('keydown', e => e.stopPropagation())
        wrapper.addEventListener('paste', e => e.stopPropagation())
        
        this._wrapper = wrapper

        this._createCodemirror()

        return wrapper
    }

    save() {
        window.blur()
        let innerHtml = this._wrapper.innerHTML
        innerHtml = innerHtml.replace('contenteditable="true"', '')
        innerHtml = innerHtml.replace('cm-activeLine', '')
        innerHtml = innerHtml.replace('cm-focused', '')

        return {
            language: this.data.language,
            code: this.codemirrorView.state.doc.sliceString(0),
            html: innerHtml
        } as CodeBlockData
    }

    renderSettings() {
        const settingsContainer = document.createElement('div');

        let languagesSelect = document.createElement("select");
        languagesSelect.classList.add("small");

        //Create and append the options
        let didSetV = false
        for (var i = 0; i < languages.length; i++) {
            if (languages[i].name.startsWith('V') && didSetV == false) {
                // insert v mode
                var option = document.createElement("option");
                option.value = 'V'
                option.text = 'V'

                if('V' == this.data.language){
                    option.selected = true
                }
                languagesSelect.appendChild(option);
                didSetV = true
            }

            var option = document.createElement("option");
            option.value = languages[i].name;
            option.text = languages[i].name;

            if(languages[i].name == this.data.language) {
                option.selected = true
            }
            languagesSelect.appendChild(option);
        }

        languagesSelect.addEventListener('change', async (event) => {
            //@ts-ignore
            const lang_val = event.target.value
            const langData = languages.find(l => l.name == lang_val)
            if (langData) {
                // this.data.code = this.codemirrorView.state.doc
                this.data.code = this.codemirrorView.state.doc.sliceString(0)
                this.data.language = lang_val
                this.codemirrorView.destroy()

                this._createCodemirror()
            } else if (lang_val == 'V') {
                // V is not in codemirror.languages
                this.data.code = this.codemirrorView.state.doc.sliceString(0)
                this.data.language = 'V'

                this.codemirrorView.destroy()
                this._createCodemirror()
            }
        });

        settingsContainer.appendChild(languagesSelect);
        new NiceSelect(languagesSelect, {searchable : true, placeholder : "Language..."});
        
        return settingsContainer;
    }

    // create codemirror state and view
    async _createCodemirror() {
        let lang_obj: any = languages.find(l => l.name == this.data.language)
        if (lang_obj) {
            lang_obj = await lang_obj.load()

        } else {
            // vlang
            lang_obj = {
                extension: vlang
            }
        }
        const startState = EditorState.create({
            doc: this.data.code,
            extensions: [
               
                keymap.of([...defaultKeymap, ...historyKeymap, indentWithTab]),
                lineNumbers(),
                highlightActiveLineGutter(),
                history(),
                indentOnInput(),
                syntaxHighlighting(defaultHighlightStyle, {
                    fallback: true,
                }),
                highlightActiveLine(),
                bracketMatching(),
                lang_obj.extension,
                oneDark,
                EditorView.lineWrapping,
                indentUnit.of("    "),
                EditorState.tabSize.of(4),
            ],
        });

        const view = new EditorView({
            state: startState,
            parent: this._wrapper,
        });

        this.codemirrorState = startState
        this.codemirrorView = view
    }
}