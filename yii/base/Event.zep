/**
 * @link http://www.yiiframework.com/
 * @copyright Copyright (c) 2008 Yii Software LLC
 * @license http://www.yiiframework.com/license/
 */

namespace yii\base;

/**
 * Event is the base class for all event classes.
 *
 * It encapsulates the parameters associated with an event.
 * The [[sender]] property describes who raises the event.
 * And the [[handled]] property indicates if the event is handled.
 * If an event handler sets [[handled]] to be true, the rest of the
 * uninvoked handlers will no longer be called to handle the event.
 *
 * Additionally, when attaching an event handler, extra data may be passed
 * and be available via the [[data]] property when the event handler is invoked.
 *
 * @author Qiang Xue <qiang.xue@gmail.com>
 * @since 2.0
 */
class Event extends \yii\base\Object
{
    /**
     * @var string the event name. This property is set by [[Component::trigger()]] and [[trigger()]].
     * Event handlers may use this property to check what event it is handling.
     */
    public name;
    /**
     * @var object the sender of this event. If not set, this property will be
     * set as the object whose "trigger()" method is called.
     * This property may also be a `null` when this event is a
     * class-level event which is triggered in a static context.
     */
    public sender;
    /**
     * @var boolean whether the event is handled. Defaults to false.
     * When a handler sets this to be true, the event processing will stop and
     * ignore the rest of the uninvoked event handlers.
     */
    public handled = false;
    /**
     * @var mixed the data that is passed to [[Component::on()]] when attaching an event handler.
     * Note that this varies according to which event handler is currently executing.
     */
    public data;

    public static _events = [];

    /**
     * Attaches an event handler to a class-level event.
     *
     * When a class-level event is triggered, event handlers attached
     * to that class and all parent classes will be invoked.
     *
     * For example, the following code attaches an event handler to `ActiveRecord`'s
     * `afterInsert` event:
     *
     * ~~~
     * Event::on(ActiveRecord::className(), ActiveRecord::EVENT_AFTER_INSERT, function ($event) {
     *     Yii::trace(get_class($event->sender) . ' is inserted.');
     * });
     * ~~~
     *
     * The handler will be invoked for EVERY successful ActiveRecord insertion.
     *
     * For more details about how to declare an event handler, please refer to [[Component::on()]].
     *
     * @param string $class the fully qualified class name to which the event handler needs to attach.
     * @param string $name the event name.
     * @param callable $handler the event handler.
     * @param mixed $data the data to be passed to the event handler when the event is triggered.
     * When the event handler is invoked, this data can be accessed via [[Event::data]].
     * @see off()
     */
    public static function on($class, string name, handler, data = null, boolean append = true)
    {
        let $class = ltrim($class, "\\");

         if !isset $static::$_events[name] {
            let $static::$_events[name] = [];
        }
        if !isset $static::$_events[name][$class] {
            let $static::$_events[name][$class] = [];
        }

         if append || ( !isset $static::$_events[name][$class] || empty $static::$_events[name][$class] ) {
            let $static::$_events[name][$class][] = [handler, data];
        } else {
            array_unshift($static::$_events[name][$class], [handler, data]);
        }
    }

    /**
     * Detaches an event handler from a class-level event.
     *
     * This method is the opposite of [[on()]].
     *
     * @param string $class the fully qualified class name from which the event handler needs to be detached.
     * @param string $name the event name.
     * @param callable $handler the event handler to be removed.
     * If it is null, all handlers attached to the named event will be removed.
     * @return boolean whether a handler is found and detached.
     * @see on()
     */
    public static function off($class, string name, handler = null)
    {
        var events, event, temp_event, temp_event2, removed_temp_event;

        let $class = ltrim($class, "\\");
        if !isset $static::$_events[name][$class] || empty $static::$_events[name][$class] {
            return false;
        }
        if typeof handler == "null" {
            let events = $static::$_events,
                event = events[name];
            unset event[$class];
            let events[name] = event,
                $static::$_events = events;
            return true;
        } else {
            var removed, i;
            let removed = false;
            let events = $static::$_events,
                event = events[name];

            if isset event[$class] && typeof event[$class] == "array" {
                for i, temp_event in event[$class] {
                    if temp_event[0] == handler {

                        let temp_event2 = event[$class];
                        unset temp_event2[i];

                        let event[$class] = temp_event2,
                            removed = true;
                    } 
                }
            }
            if (removed) {
                let removed_temp_event = event[$class],
                    removed_temp_event = array_values(removed_temp_event),
                    event[$class] = removed_temp_event,
                    events[name] = event[$class],
                    $static::$_events = events;
            }

            return removed;
        }
    }

    /**
     * Detaches all registered class-level event handlers.
     * @see on()
     * @see off()
     * @since 2.0.10
     */
    public static function offAll()
    {
        let $static::$_events = [];
    }

    /**
     * Returns a value indicating whether there is any handler attached to the specified class-level event.
     * Note that this method will also check all parent classes to see if there is any handler attached
     * to the named event.
     * @param string|object $class the object or the fully qualified class name specifying the class-level event.
     * @param string $name the event name.
     * @return boolean whether there is any handler attached to the event.
     */
    public static function hasHandlers($class, string name) -> bool
    {
        if !isset $static::$_events[name] || empty $static::$_events[name] {
            return false;
        }

        if typeof $class == "object" {
            let $class = get_class($class);
        } else {
            let $class = ltrim($class, "\\");
        }
        var classes;
        let classes = array_merge(
                    [$class],
                    class_parents($class, true),
                    class_implements($class, true)
                );

        for $class in classes {
            if isset $static::$_events[name][$class] && !empty $static::$_events[name][$class] {
                return true;
            }
        }
        return false;
    }

    /**
     * Triggers a class-level event.
     * This method will cause invocation of event handlers that are attached to the named event
     * for the specified class and all its parent classes.
     * @param string|object $class the object or the fully qualified class name specifying the class-level event.
     * @param string $name the event name.
     * @param Event $event the event parameter. If not set, a default [[Event]] object will be created.
     */
    public static function trigger($class, string name, event = null)
    {
        var events;
        let events = $static::$_events;

        if !isset events[name] || empty events[name]{
            return;
        }

        if typeof event == "null" {
            let event = new $static;
        }

        let event->handled = false;
        let event->name = name;

        if typeof $class == "object" {
            if typeof event->sender == "null" {
                let event->sender = $class;
            }
            let $class = get_class($class);
        } else {
            let $class = ltrim($class, "\\");
        }

        var classes;
        let classes = array_merge(
            [$class],
            class_parents($class, true),
            class_implements($class, true)
        );

        for $class in classes {
            if  isset $static::$_events[name][$class] && !empty $static::$_events[name][$class] {
                var handler;
                for handler in $static::$_events[name][$class] {
                    let event->data = handler[1];
                    call_user_func(handler[0], event);
                    if (event->handled) {
                        return;
                    }
                }
            }
        }
    }
}