import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

// Settings shown in DMS Settings > Plugins. Empty values fall back to the vault's .obsidian config
// (daily-notes / templates / app), then to SuperNote's own defaults. Vaults are managed in the panel.
PluginSettings {
    id: root

    pluginId: "supernote"

    Column {
        width: parent.width
        spacing: Theme.spacingL

        StyledText {
            text: "SuperNote"
            font.pixelSize: Theme.fontSizeLarge
            font.weight: Font.Bold
            color: Theme.surfaceText
        }

        StyledText {
            width: parent.width
            text: "Markdown vault editor. Leave a field empty to use the vault's Obsidian setting (if it has one) or the default. Vaults are added and switched from the vault menu in the panel."
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
            wrapMode: Text.WordWrap
        }

        StringSetting {
            settingKey: "dailyFolder"
            label: "Daily notes folder"
            description: "Where today's note lives. Default: Daily"
            placeholder: "Daily"
        }

        StringSetting {
            settingKey: "dailyFormat"
            label: "Daily note name"
            description: "Date format (YYYY MM DD dddd MMMM, [literal]). Slashes make sub folders. Default: YYYY-MM-DD"
            placeholder: "YYYY-MM-DD"
        }

        StringSetting {
            settingKey: "dailyTemplate"
            label: "Daily note template"
            description: "Vault path of a template note, e.g. Templates/Daily. Default: none (empty note)"
            placeholder: "Templates/Daily"
        }

        StringSetting {
            settingKey: "templatesFolder"
            label: "Templates folder"
            description: "Notes here appear in \"New note from template\" and the / menu. Variables: {{title}} {{date}} {{time}} {{date:FORMAT}} {{cursor}}. Default: Templates"
            placeholder: "Templates"
        }

        StringSetting {
            settingKey: "attachmentsFolder"
            label: "Attachments folder"
            description: "Where pasted images go. \"/\" = vault root, \"./sub\" = next to the note. Default: Attachments"
            placeholder: "Attachments"
        }

        StringSetting {
            settingKey: "inboxFolder"
            label: "Inbox folder"
            description: "Ctrl+Enter in the quick capture box saves a note here. Default: Inbox"
            placeholder: "Inbox"
        }

        StringSetting {
            settingKey: "editorFontSize"
            label: "Editor font size"
            description: "Pixels. Default: 15"
            placeholder: "15"
        }
    }
}
