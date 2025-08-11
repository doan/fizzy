module ConversationsHelper
  def conversation_previous_page_link(message, **options)
    return unless message

    url = conversation_messages_path(before: message)

    options[:id] ||= dom_id(message.conversation, :load_more)
    options[:data] ||= {}
    options[:data] = options[:data].reverse_merge(
      turbo_stream: true,
      controller: "fetch-on-visible",
      fetch_on_visible_url_value: url
    )

    link_to "Load more", url, **options
  end
end
