import type { BlockAPI } from '@editorjs/editorjs'

import '@/plugins/tools/alert/alert.scss'

//@ts-ignore
import NiceSelect from "nice-select2/dist/js/nice-select2"
import "nice-select2/dist/css/nice-select2.css"

type AlertType = 'info' | 'success' | 'warn' | 'danger'

interface AlertData {
    typ: AlertType
    text: string
}

export default class AlertBlock {
    data: AlertData
    api: BlockAPI

    //@ts-ignore
    _alert: HTMLDivElement

    constructor({ data, api}: any) {
        this.data = data
        this.api = api

        if (this.data.typ == undefined) {
            this.data.typ = 'info'
        }
    }

    // toolbox display
    static get toolbox() {
        return {
            title: 'Alert',
            icon: '<svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg"><g id="SVGRepo_bgCarrier" stroke-width="0"></g><g id="SVGRepo_tracerCarrier" stroke-linecap="round" stroke-linejoin="round"></g><g id="SVGRepo_iconCarrier"> <path d="M21 12C21 16.9706 16.9706 21 12 21C7.02944 21 3 16.9706 3 12C3 7.02944 7.02944 3 12 3C16.9706 3 21 7.02944 21 12Z" stroke="#000000" stroke-width="2"></path> <path d="M12 8L12 13" stroke="#000000" stroke-width="2" stroke-linecap="round"></path> <path d="M12 16V15.9888" stroke="#000000" stroke-width="2" stroke-linecap="round"></path> </g></svg>'
        }
    }

    // Empty alert is not empty Block
    static get contentless() {
        return true;
    }

    // Allow to press enter inside Alert
    static get enableLineBreaks() {
        return true;
    }
    

    render() {
        const wrapper = document.createElement('div')
        wrapper.classList.add('cdx-block')

        const textarea = document.createElement('div')
        textarea.classList.add('cdx-block')
        textarea.classList.add('cdx-input')
        textarea.classList.add('cdx-alert')
        textarea.classList.add(this.data.typ)
        textarea.contentEditable = 'true'
        textarea.innerHTML = this.data.text || '';
        textarea.dataset.placeholder = 'Enter an alert'
        this._alert = textarea;
        
        wrapper.appendChild(textarea)

        return wrapper
    }

    save(alertElement: HTMLDivElement) {
        return Object.assign(this.data, {
            text: this._alert.innerHTML
        })
    }

    renderSettings() {
        const settingsContainer = document.createElement('div')

        const label = document.createElement('p')
        label.classList.add('ce-popover-item__title')
        label.style.padding = '3px'
        label.style.marginBottom = '1px'
        label.innerHTML = 'Alert type:'
        settingsContainer.appendChild(label)
        
        const typeSelect = document.createElement('select')
        typeSelect.classList.add('small')

        let opt_info = document.createElement('option')
        opt_info.value = 'info'
        opt_info.text = 'Info'
        opt_info.selected = this.data.typ == 'info'
        typeSelect.appendChild(opt_info)

        let opt_success = document.createElement('option')
        opt_success.value = 'success'
        opt_success.text = 'Success'
        opt_success.selected = this.data.typ == 'success'
        typeSelect.appendChild(opt_success)

        let opt_warn = document.createElement('option')
        opt_warn.value = 'warn'
        opt_warn.text = 'Warn'
        opt_warn.selected = this.data.typ == 'warn'
        typeSelect.appendChild(opt_warn)

        let opt_danger = document.createElement('option')
        opt_danger.value = 'danger'
        opt_danger.text = 'Danger'
        opt_danger.selected = this.data.typ == 'danger'
        typeSelect.appendChild(opt_danger)

        typeSelect.addEventListener('change', e => {
            this._alert.classList.remove(this.data.typ)
            // @ts-ignore
            this.data.typ = e.target.value
            this._alert.classList.add(this.data.typ)
        })
        
        settingsContainer.appendChild(typeSelect)
        new NiceSelect(typeSelect, {searchable : false, placeholder : "Alert Type"});


        return settingsContainer
    }
}