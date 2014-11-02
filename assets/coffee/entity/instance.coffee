class Cruddy.Entity.Instance extends Backbone.Model

    constructor: (attributes, options) ->
        @entity = options.entity
        @related = {}
        @idAttribute = @entity.getPrimaryKey()
        @meta = {}

        super

    initialize: (attributes, options) ->
        @original = _.clone attributes

        @on "error", @handleErrorEvent, this
        @on "invalid", @handleInvalidEvent, this
        @on "sync", @handleSyncEvent, this
        @on "destroy", @handleDestroyEvent, this

        @on event, @triggerRelated(event), this for event in ["sync", "request"]

        this

    handleSyncEvent: (model, resp) ->
        @original = _.clone @attributes

        @setMetaFromResponse resp

        this

    setMetaFromResponse: (resp) ->
        @meta = _.clone resp.meta if resp.meta?

        return this

    # Get a function handler that passes events to the related models
    triggerRelated: (event) ->
        slice = Array.prototype.slice

        (model) ->
            for id, related of @related
                relation = @entity.getRelation id
                relation.triggerRelated.call relation, event, related, slice.call arguments, 1

            this

    handleInvalidEvent: (model, errors) ->
        # Trigger errors for related models
        @entity.getRelation(id).processErrors model, errors[id] for id, model of @related when id of errors

        this

    handleErrorEvent: (model, xhr) ->
        @trigger "invalid", this, xhr.responseJSON if xhr.status is 400

        return

    handleDestroyEvent: (model) ->
        @isDeleted = yes

        return

    validate: ->
        @set "errors", {}
        null

    link: -> @entity.link if @isNew() then "create" else @id

    url: -> @entity.url @id

    set: (key, val, options) ->
        if typeof key is "object"
            attrs = key
            options = val
            is_copy = options?.is_copy

            for id in @entity.get "related" when id of attrs
                relation = @entity.getRelation id
                relationAttrs = attrs[id]

                if is_copy
                    related = @related[id] = relationAttrs
                else
                    related = @related[id] = relation.createInstance this, relationAttrs

                # Attribute will now hold instance
                attrs[id] = related

        super

    sync: (method, model, options) ->
        if method in ["update", "create"]
            # Form data will allow us to upload files via AJAX request
            options.data = new AdvFormData(options.attrs ? @attributes).original

            # Set the content type to false to let browser handle it
            options.contentType = false
            options.processData = false

        super

    parse: (resp) -> resp.attributes

    copy: ->
        copy = @entity.createInstance()

        copy.set @getCopyableAttributes(copy),
            silent: yes
            is_copy: yes

        copy

    getCopyableAttributes: (copy) -> @entity.getCopyableAttributes copy, @attributes

    hasChangedSinceSync: ->
        return yes for key, value of @attributes when if key of @related then @entity.getRelation(key).hasChangedSinceSync value else not _.isEqual value, @original[key]

        no

    # Get whether is allowed to save instance
    isSaveable: -> (@isNew() and @entity.createPermitted()) or (not @isNew() and @entity.updatePermitted())

    serialize: -> if @isDeleted then { id: @id, isDeleted: yes } else { attributes: @attributes, id: @id }

    # Get current action on the model
    action: -> if @isNew() then "create" else "update"

    getTitle: -> if @isNew() then Cruddy.lang.model_new_record else @meta.title