// @ts-nocheck
import type { EditorConfig } from '@editorjs/editorjs'
import Embed from '@editorjs/embed'
import LinkTool from '@editorjs/link'
import Paragraph from '@editorjs/paragraph'
import Quote from '@editorjs/quote'
import NestedList from '@editorjs/nested-list'
import MermaidTool from 'editorjs-mermaid'
import ImageTool from '@editorjs/image'
import Header from '@editorjs/header'
import Table from '@editorjs/table'
import DragDrop from 'editorjs-drag-drop'
import ColorPlugin from 'editorjs-text-color-plugin'
import SimpleImage from '@/plugins/tools/simpleImage.js'

interface EditorUrlConfig {
    uploadFile: string
    uploadUrl: string
    linkEndpoint: string
}

export function createEditor(id : string, blockData: any, urlConf: EditorUrlConfig,  onChange: EditorConfig['onChange']) {
    const editor = new EditorJS({
        data: {
            blocks: blockData,
        },
        holder: id,
        tools: {
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
            // image: {
            //     class: ImageTool,
            //     config: {
            //         // endpoints : {
            //         //     byFile: urlConf.uploadFile, // Your backend file uploader endpoint
            //         //     byUrl: urlConf.uploadUrl, // Your endpoint that provides uploading by Url
            //         // }
            //         uploader: {
            //             async uploadByFile(file: any) {
            //                 console.log(file)
            //             },
            //             async uploadByUrl(url: string) {
            //                 return {
            //                     success: 1,
            //                     file: { url }
            //                 }
            //             }
            //         }
            //     }
            // },
            image: SimpleImage,
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
