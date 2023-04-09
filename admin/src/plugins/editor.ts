// @ts-nocheck
import axios from '@/plugins/axios'
import type { EditorConfig } from '@editorjs/editorjs'
import Embed from '@editorjs/embed'
import LinkTool from '@editorjs/link'
import Paragraph from '@editorjs/paragraph'
import Quote from '@editorjs/quote'
// import NestedList from '@editorjs/nested-list'
import MermaidTool from 'editorjs-mermaid'
import ImageTool from '@editorjs/image'
import Header from '@editorjs/header'
import Table from '@editorjs/table'
import DragDrop from 'editorjs-drag-drop'
import ColorPlugin from 'editorjs-text-color-plugin'
import CodeBlock from '@/plugins/tools/code'

// pass endpoint strings
interface EditorUrlConfig {
    uploadFile: string
    uploadUrl: string // TODO: maybe upload images from url the local server??
    linkEndpoint: string
}

export function createEditor(id : string, blockData: any, urlConf: EditorUrlConfig,  onChange: EditorConfig['onChange']) {
    const editor = new EditorJS({
        data: {
            blocks: blockData,
        },
        holder: id,
        tools: {
            code: {
                class: CodeBlock
            },
            colors: {
                class: ColorPlugin,
                config: {
                    type: 'text',
                    customPicker: true
                }
            },
            heading: {
                class: Header,
                config: {
                    defaultLevel: 1,
                    levels: [1,2,3]
                }
            },
            paragraph: {
                class: Paragraph,
                inlineToolbar: true
            },
            link: {
                class: LinkTool,
                config: {
                    endpoint: urlConf.linkEndpoint
                }
            },
            // TODO: lists will nest in a JSON structure, will enable lists when V
            // supports recursive structs.
            // list: {
            //     class: NestedList,
            //     inlineToolbar: true,
            //     config: {
            //         defaultStyle : 'ordered'
            //     }
            // },
            quote: {
                class: Quote,
                inlineToolbar: true,
                config: {
                    quotePlaceholder : 'Enter a quote',
                    captionPlaceholder : 'Quote\'s author'
                }
            },
            image: {
                class: ImageTool,
                config: {
                    uploader: {
                        async uploadByFile(file: any) {
                            const body = new FormData()
                            body.append('image', file)
                            const resp = await axios.post(urlConf.uploadFile, body)
                            
                            // transform img url data: endpoint will only return `uploads/img/<img_path>`
                            if (resp.data.success) {
                                resp.data.file.url = import.meta.env.VITE_BASE_URL + resp.data.file.url
                            }
                            return resp.data
                        },
                        async uploadByUrl(url: string) {
                            return {
                                success: 1,
                                file: {
                                    url
                                }
                            }
                        }
                    }
                }
            },
            table: {
                class: Table,
                inlineToolbar: true,
                config: {
                    withHeadings: true
                }
            },
            mermaid: MermaidTool,
            embed: {
                class: Embed
            }
        },
        //@ts-ignore
        logLevel: 'ERROR',
        onReady: () => {
            MermaidTool.config({'theme': 'neutral'})
            new DragDrop(editor);
        },
        autofocus: true,
        onChange,
    })
    return editor
}
