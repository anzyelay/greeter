
public class TextShadowEffect : Clutter.Effect {
    int _offset_y;
    public int offset_y {
        get { return _offset_y; }
        set { _offset_y = value; this.update (); }
    }
    int _offset_x;
    public int offset_x {
        get { return _offset_x; }
        set { _offset_x = value; this.update (); }
    }
    uint8 _opacity;
    public uint8 opacity {
        get { return _opacity; }
        set { _opacity = value; this.update (); }
    }
    
    public TextShadowEffect (int offset_x, int offset_y, uint8 opacity) {
        this._offset_x = offset_x;
        this._offset_y = offset_y;
        this._opacity  = opacity;
    }
    
    public override bool pre_paint () {
        var layout = ((Clutter.Text)this.get_actor ()).get_layout ();
        Cogl.pango_render_layout (layout, this.offset_x, this.offset_y, 
            Cogl.Color.from_4ub (0, 0, 0, opacity), 0);
        return true;
    }
    
    public void update () {
        if (this.get_actor () != null)
            this.get_actor ().queue_redraw ();
    }
}

public class PopOver : GtkClutter.Actor {
    
    Granite.Drawing.BufferSurface buffer;
    Gtk.EventBox container;
    
    public PopOver () {
        
        this.container = new Gtk.EventBox ();
        this.container.visible_window = false;
        this.container.margin = 30;
        this.container.margin_top = 40;
        this.container.margin_bottom = 25;
        this.container.get_style_context ().add_class ("content-view");
        (this.get_widget () as Gtk.Container).add (this.container);
        
        this.reactive = true;
        
        var w = -1; var h = -1; var ARROW_HEIGHT = 10; var ARROW_WIDTH = 20;
        this.get_widget ().size_allocate.connect ( () => {
            if (this.contents.get_allocated_width () == -1 && 
                this.contents.get_allocated_height () == -1)
                return;
            w = this.contents.get_allocated_width ();
            h = this.contents.get_allocated_height ();
            
            var x = 20;
            var y = 20;
            
            this.buffer = new Granite.Drawing.BufferSurface ((int)width, (int)height);
            Granite.Drawing.Utilities.cairo_rounded_rectangle (buffer.context, x, y+ARROW_HEIGHT,
                                                           (int)width - x*2, (int)height - y*2, 5);
            buffer.context.move_to ((int)(width-45), y + ARROW_HEIGHT);
            buffer.context.rel_line_to (ARROW_WIDTH / 2.0, -ARROW_HEIGHT);
            buffer.context.rel_line_to (ARROW_WIDTH / 2.0, ARROW_HEIGHT);
            buffer.context.close_path ();
            
            buffer.context.set_source_rgba (0, 0, 0, 0.8);
            buffer.context.fill_preserve ();
            buffer.exponential_blur (10);
            
            buffer.context.set_source_rgb (1, 1, 1);
            buffer.context.fill ();
        });
        this.get_widget ().draw.connect ( (ctx) => {
            ctx.rectangle (0, 0, w, h);
            ctx.set_operator (Cairo.Operator.SOURCE);
            ctx.set_source_rgba (0, 0, 0, 0);
            ctx.fill ();
            
            ctx.set_source_surface (buffer.surface, 0, 0);
            ctx.paint ();
            
            return false;
        });
        this.leave_event.connect ( () => {
            this.animate (Clutter.AnimationMode.EASE_OUT_QUAD, 200, opacity:0).
                completed.connect ( () => {
                this.get_stage ().remove_child (this);
                this.destroy ();
            });
            return true;
        });
        
        this.opacity = 0;
        this.animate (Clutter.AnimationMode.EASE_OUT_QUAD, 200, opacity:255);
    }
    
    
    public Gtk.Widget get_content_area () {
        return this.container;
    }
    
    
}

public static int main (string [] args) {
    
    var init = GtkClutter.init (ref args);
    if (init != Clutter.InitError.SUCCESS)
        error ("Clutter could not be intiailized");
    
    var greeter = new LightDM.Greeter ();
    var w = new Gtk.Window ();
    var c = new GtkClutter.Embed ();
    var l = new LoginBox (greeter);
    var fadein = new Clutter.Rectangle.with_color ({0, 0, 0, 255});
    
    greeter.show_message.connect ( (text, type) => {
        if (type == LightDM.MessageType.ERROR)
            l.wrong_pw ();
    });
    greeter.show_prompt.connect  ( (text, type) => {
        greeter.respond (l.password.text);
        warning ("Password text: %s", l.password.text);
    });
    greeter.authentication_complete.connect ( () => {
        if (greeter.is_authenticated) {
            warning ("Authenticated!");
            try {
                fadein.show ();
                fadein.animate (Clutter.AnimationMode.EASE_OUT_QUAD, 1000, opacity:255);
                greeter.start_session_sync (l.current_session);
            } catch (Error e) { warning (e.message); }
            Gtk.main_quit ();
        } else {
            warning ("Authentication failed!");
        }
    });
    l.login.clicked.connect ( () => {
        if (l.current_user == null)
            greeter.authenticate_as_guest ();
        else
            greeter.authenticate (l.current_user.name);
    });
    
    try {
        greeter.connect_sync ();
    } catch (Error e) {
        warning ("Couldn't connect, %s", e.message);
        Posix.exit (Posix.EXIT_FAILURE);
    }
    
    
    var u = LightDM.UserList.get_instance ();
    
    /*some settings*/
    Intl.setlocale (LocaleCategory.ALL, "");
    Intl.bind_textdomain_codeset ("pantheon-greeter", "UTF-8");
    Intl.textdomain ("pantheon-greeter");
    
    Gdk.get_default_root_window ().set_cursor (new Gdk.Cursor (Gdk.CursorType.LEFT_PTR));
    Gtk.Settings.get_default ().gtk_theme_name = "elementary";
    Gtk.Settings.get_default ().gtk_icon_theme_name = "elementary";
    Gtk.Settings.get_default ().gtk_font_name = "Droid Sans";
    Gtk.Settings.get_default ().gtk_xft_dpi= (int) (1024 * 96);
    Gtk.Settings.get_default ().gtk_xft_antialias = 1;
    Gtk.Settings.get_default ().gtk_xft_hintstyle = "hintslight";
    Gtk.Settings.get_default ().gtk_xft_rgba = "rgb";
    Gtk.Settings.get_default ().gtk_cursor_blink = true;
    
    (c.get_stage () as Clutter.Stage).color = {0, 0, 0, 255};
    c.get_stage ().realize ();
    c.get_stage ().add_child (l.background);
    c.get_stage ().add_child (l.background_s);
    c.get_stage ().add_child (l);
    
    var darken = new Clutter.Rectangle.with_color ({0, 0, 0, 25});
    c.get_stage ().add_child (darken);
    
    l.background.add_constraint (new Clutter.BindConstraint (c.get_stage (), Clutter.BindCoordinate.WIDTH, 0));
    l.background.add_constraint (new Clutter.BindConstraint (c.get_stage (), Clutter.BindCoordinate.HEIGHT, 0));
    l.background_s.add_constraint (new Clutter.BindConstraint (c.get_stage (), Clutter.BindCoordinate.WIDTH, 0));
    l.background_s.add_constraint (new Clutter.BindConstraint (c.get_stage (), Clutter.BindCoordinate.HEIGHT, 0));
    darken.add_constraint (new Clutter.BindConstraint (c.get_stage (), Clutter.BindCoordinate.WIDTH, 0));
    darken.add_constraint (new Clutter.BindConstraint (c.get_stage (), Clutter.BindCoordinate.HEIGHT, 0));
    
    Gdk.Rectangle geom;
    Gdk.Screen.get_default ().get_monitor_geometry (Gdk.Screen.get_default ().get_primary_monitor (), out geom);
    
    w.get_screen ().monitors_changed.connect ( () => {
        Gdk.Rectangle geometry;
        Gdk.Screen.get_default ().get_monitor_geometry (
            Gdk.Screen.get_default ().get_primary_monitor (), out geometry);
        w.resize (geometry.width, geometry.height);
    });
    
    l.width  = 500;
    l.height = 245;
    l.y      = geom.height / 2 - l.height / 2;
    l.x      = -l.width;
    
    l.animate (Clutter.AnimationMode.EASE_OUT_QUAD, 400, x:100.0f).completed.connect ( () => {
        l.set_position (Math.floorf (l.x), Math.floorf (l.y));
    });
    l.set_size     (Math.ceilf (l.width), Math.ceilf (l.height));
    
    
    var current_user = 0;
    for (var i=0;i<u.users.length ();i++) {
        if (u.users.nth_data (i).name == greeter.select_user_hint)
            current_user = i;
    }
    
    var name_container = new Clutter.Group ();
    name_container.y = l.y;
    name_container.x = 100;
    
    /*the other names*/
    for (var i=0;i<u.users.length () + 1;i++) {
        if (i == u.users.length () && !greeter.has_guest_account_hint)
            continue;
        var text = new Clutter.Text ();
        text.color = {255, 255, 255, 255};
        if (i == u.users.length ())
            text.set_markup ("<span face='Open Sans Light' font='24'>Guest session</span>");
        else
            text.set_markup (LoginBox.get_user_markup (u.users.nth_data (i)));
        text.height = 75;
        text.width = l.width - 100;
        text.x = 155;
        text.y = i * (text.height + 60) + 120;
        text.add_effect (new TextShadowEffect (0, 1, 240));
        text.reactive = true;
        text.button_release_event.connect ( () => {
            var idx = name_container.get_children ().index (text);
            current_user = idx;
            message ("Setting to %i by click", idx);
            l.set_user (u.users.nth_data (idx));
            name_container.animate (Clutter.AnimationMode.EASE_OUT_QUAD, 400, 
                y:l.y-idx*150.0f);
            return true;
        });
        name_container.add_child (text);
    }
    c.get_stage ().add_child (name_container);
    
    c.add_events (Gdk.EventMask.BUTTON_RELEASE_MASK);
    c.key_release_event.connect ( (e) => {
        if (e.keyval == Gdk.Key.Up) {
            current_user --;
            if (current_user-1<0)
                current_user = 0;
        } else if (e.keyval == Gdk.Key.Down) {
            current_user ++;
            var sum = (greeter.has_guest_account_hint)?u.users.length ()+1:u.users.length ();
            if (current_user >= sum)
                current_user = (int)((greeter.has_guest_account_hint)?u.users.length ():u.users.length ()-1);
        } else {
            return false;
        }
        name_container.animate (Clutter.AnimationMode.EASE_OUT_QUAD, 400, 
            y:l.y-current_user*150.0f);
        l.set_user (u.users.nth_data (current_user));
        return true;
    });
    
    /*shutdown and so on thing*/
    var shutdown = new GtkClutter.Texture ();
    try {
        shutdown.set_from_icon_name (new Gtk.Image (), 
            "system-shutdown-symbolic", Gtk.IconSize.MENU);
    } catch (Error e) { warning (e.message); }
    shutdown.x = geom.width - shutdown.width - 10;
    shutdown.y = 10;
    shutdown.reactive = true;
    shutdown.button_press_event.connect ( () => {
        var pop = new PopOver ();
        var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        if (LightDM.get_can_suspend ()) {
            var but = new Gtk.Button.with_label (_("Suspend"));
            but.clicked.connect ( () => {
                try {
                    LightDM.suspend ();
                } catch (Error e) { warning (e.message); }
            });
            box.pack_start (but, false);
        }
        if (LightDM.get_can_hibernate ()) {
            var but = new Gtk.Button.with_label (_("Hibernate"));
            but.clicked.connect ( () => {
                try {
                    LightDM.hibernate ();
                } catch (Error e) { warning (e.message); }
            });
            box.pack_start (but, false);
        }
        if (LightDM.get_can_restart ()) {
            var but = new Gtk.Button.with_label (_("Restart"));
            but.clicked.connect ( () => {
                try {
                    LightDM.restart ();
                } catch (Error e) { warning (e.message); }
            });
            box.pack_start (but, false);
        }
        if (LightDM.get_can_shutdown ()) {
            var but = new Gtk.Button.with_label (_("Suspend"));
            but.clicked.connect ( () => {
                try {
                    LightDM.shutdown ();
                } catch (Error e) { warning (e.message); }
            });
            box.pack_start (but, false);
        }
        ((Gtk.Container)pop.get_content_area ()).add (box);
        pop.x =  geom.width - 110;
        pop.y = 10;
        c.get_stage ().add_child (pop);
        pop.get_widget ().show_all ();
        return true;
    });
    c.get_stage ().add_child (shutdown);
    
    /*time label*/
    var time_ac = new GtkClutter.Actor ();
    var time = new Gtk.Label ("");
    var time_css = new Gtk.CssProvider ();
    time_ac.get_widget ().draw.connect ( (ctx) => {
        ctx.rectangle (0, 0, time_ac.width, time_ac.height);
        ctx.set_operator (Cairo.Operator.SOURCE);
        ctx.set_source_rgba (0, 0, 0, 0);
        ctx.fill ();
        return false;
    });
    time.justify = Gtk.Justification.CENTER;
    try {
        time_css.load_from_data ("*{color:#fff;text-shadow:0 1 2 #000;}", -1);
    } catch (Error e) { warning (e.message); }
    time.get_style_context ().add_provider (time_css, 20000);
    
    Timeout.add (1000,  () => {
        var date = new GLib.DateTime.now_local ();
        time.set_markup (date.format ("<span face='Open Sans Light' font='24'>%A, %B %eth</span>\n<span face='Raleway' font='72'>%l:%M %p</span>"));
        return true;
    });
    ((Gtk.Container)time_ac.get_widget ()).add (time);
    time_ac.get_widget ().show_all ();
    time_ac.width = 500;
    time_ac.height = 150;
    time_ac.x = geom.width - time_ac.width - 100;
    time_ac.y = geom.height / 2 - time_ac.height / 2;
    c.get_stage ().add_child (time_ac);
    
    
    name_container.animate (Clutter.AnimationMode.EASE_OUT_QUAD, 400, 
        y:l.y-current_user*130.0f);
    l.set_user (u.users.nth_data (current_user));
    l.raise_top ();
    l.password.grab_focus ();
    
    /*black fadein thing*/
    fadein.add_constraint (new Clutter.BindConstraint (c.get_stage (), 
        Clutter.BindCoordinate.WIDTH, 0));
    fadein.add_constraint (new Clutter.BindConstraint (c.get_stage (), 
        Clutter.BindCoordinate.HEIGHT, 0));
    c.get_stage ().add_child (fadein);
    fadein.raise_top (); //TODO decrease optimize this
    fadein.animate (Clutter.AnimationMode.EASE_IN_SINE, 1000, opacity:0).completed.connect ( () => {
        fadein.hide ();
    });
    
    w.add (c);
    w.set_default_size (geom.width, geom.height);
    w.move (geom.x, geom.y);
    w.show_all ();
    w.fullscreen ();
    
    Gtk.main ();
    
    return Posix.EXIT_SUCCESS;
}

