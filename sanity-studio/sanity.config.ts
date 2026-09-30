// Studio for the test copy (testUNIDCOM, ld5jhf23) — never the agency's vj0axykv.
// ponytail: schema rebuilt from field names in sanity-dump/, not the agency's own; swap in theirs if they share it.
import {defineConfig, defineField, defineType} from 'sanity'
import {structureTool} from 'sanity/structure'
import {visionTool} from '@sanity/vision'

const titled = (name: string, title: string) =>
  defineType({name, title, type: 'document', fields: [defineField({name: 'title', type: 'string'})]})

const member = defineType({
  name: 'member',
  title: 'Member',
  type: 'document',
  fields: [
    defineField({name: 'name', type: 'string'}),
    defineField({name: 'slug', type: 'slug', options: {source: 'name'}}),
    defineField({name: 'type', type: 'reference', to: [{type: 'memberType'}]}),
    defineField({name: 'photo', type: 'image'}),
    defineField({name: 'shortBio', type: 'text', rows: 8}),
    defineField({name: 'researchInterests', type: 'text', rows: 3}),
    defineField({name: 'email', type: 'string'}),
    defineField({name: 'orcid', title: 'ORCID', type: 'string'}),
    defineField({name: 'cienciaId', title: 'Ciência ID', type: 'string'}),
    defineField({name: 'boardRole', type: 'string'}),
    defineField({name: 'unlistedFromPeopleList', type: 'boolean'}),
    defineField({name: 'noPublicPage', type: 'boolean'}),
    defineField({name: 'unlockSlug', type: 'boolean'}),
    defineField({name: 'migrated', type: 'boolean', readOnly: true}),
  ],
  preview: {select: {title: 'name', subtitle: 'type.title', media: 'photo'}},
})

const researchOutput = defineType({
  name: 'researchOutput',
  title: 'Research output',
  type: 'document',
  fields: [
    defineField({name: 'title', type: 'string'}),
    defineField({name: 'year', type: 'number'}),
    defineField({name: 'citation', type: 'text', rows: 4}),
    defineField({name: 'link', type: 'url'}),
    defineField({name: 'members', type: 'array', of: [{type: 'reference', to: [{type: 'member'}]}]}),
    defineField({name: 'migrated', type: 'boolean', readOnly: true}),
  ],
  preview: {select: {title: 'title', subtitle: 'year'}},
})

export default defineConfig({
  name: 'unidcom-test',
  title: 'UNIDCOM test',
  projectId: 'ld5jhf23',
  dataset: 'production',
  plugins: [structureTool(), visionTool()],
  schema: {
    types: [member, researchOutput, titled('memberType', 'Member type'), titled('outputType', 'Output type')],
  },
})
