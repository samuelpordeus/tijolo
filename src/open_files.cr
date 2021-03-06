class OpenFiles
  include UiBuilderHelper

  getter model : Gtk::ListStore
  getter sorted_model : Gtk::TreeModelSort

  @stack : Gtk::Stack

  @files = [] of TextView
  @sorted_files = [] of TextView # Files reverse sorted by last used
  @sorted_files_index = 0        # Selected file on open files model
  @last_used_counter = 0         # Counter used to sort open files, last used first

  @on_selected_open_file_change : Proc(Int32, Nil)?

  # Open files model columns
  OPEN_FILES_LABEL     = 0
  OPEN_FILES_VIEW_ID   = 1
  OPEN_FILES_LAST_USED = 2

  Log = ::Log.for("OpenFiles")

  delegate empty?, to: @files

  def initialize(@stack : Gtk::Stack)
    @model = Gtk::ListStore.new(3, {GObject::Type::UTF8, GObject::Type::UINT64, GObject::Type::ULONG})
    @sorted_model = Gtk::TreeModelSort.new(model: @model)
    @sorted_model.set_sort_column_id(OPEN_FILES_LAST_USED, :descending)

    create_empty_view
  end

  def create_empty_view
    builder = builder_for("no_view")
    editor = Gtk::Widget.cast(builder["root"])
    @stack.add(editor)
    builder.unref
  end

  def view(id : UInt64) : TextView?
    @files.each do |view|
      return view if view.object_id == id
    end
    nil
  end

  def view(file_path : String) : TextView?
    @files.each do |view|
      return view if view.file_path.to_s == file_path
    end
    nil
  end

  def current_view : TextView?
    view_id = @stack.visible_child_name
    @files.find { |view| view.id == view_id }
  end

  def <<(text_view : TextView) : TextView
    @stack.add_named(text_view.widget, text_view.id)

    @files << text_view
    @sorted_files << text_view
    @sorted_files_index = @sorted_files.size - 1
    @model.append({0, 1, 2}, {text_view.label, text_view.object_id, last_used_counter})

    reveal_view(text_view)
    text_view
  end

  def last_used_counter
    @last_used_counter += 1
  end

  def on_selected_open_file_change(&block : Proc(Int32, Nil))
    @on_selected_open_file_change = block
  end

  private def reveal_view(view : TextView)
    @stack.visible_child_name = view.id
    view.grab_focus

    @on_selected_open_file_change.try(&.call(@sorted_files.size - (@sorted_files_index + 1)))
  end

  private def reorder_open_files(new_selected_index)
    @sorted_files.push(@sorted_files.delete_at(new_selected_index))
    @sorted_files_index = @sorted_files.size - 1

    idx = @files.index(@sorted_files[@sorted_files_index])
    @model.set(idx, {OPEN_FILES_LAST_USED}, {last_used_counter}) unless idx.nil?
  end

  def switch_current_view(reorder : Bool)
    return if @files.size < 2

    if reorder
      reorder_open_files(@sorted_files_index)
    else
      @sorted_files_index -= 1
      @sorted_files_index = @sorted_files.size - 1 if @sorted_files_index < 0
    end

    reveal_view(@sorted_files[@sorted_files_index])
  end

  def show_view(view : TextView)
    idx = @sorted_files.index(view)
    if idx.nil?
      Log.warn { "Unknow view: #{view.label}" }
      return
    end

    reorder_open_files(idx)
    reveal_view(view)
  end

  def close_current_view
    return if @files.empty?

    view_id = @stack.visible_child_name
    idx = @files.index { |view| view.id == view_id }

    return if idx.nil?

    view = @files[idx]
    @files.delete(view)
    @sorted_files.delete(view)
    @sorted_files_index = @sorted_files.size - 1

    @model.remove_row(idx)
    @stack.remove(@stack.visible_child.not_nil!)

    reveal_view(@sorted_files.last) if @sorted_files.any?
  end
end
