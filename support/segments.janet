(import ./pegs)

(defn parse-buffer
  [buf]
  (var segments @[])
  (var from 0)
  (loop [parsed :iterate (peg/match pegs/jg-pos buf from)]
    (when (dyn :debug)
      (eprintf "parsed: %j" parsed))
    (when (not parsed)
      (break))
    (def segment (first parsed))
    (assert segment
            (string "Unexpectedly did not find segment in: " parsed))
    (array/push segments segment)
    (set from (segment :end)))
  segments)

(defn find-comment-blocks
  [segments]
  (var comment-blocks @[])
  (loop [i :range [0 (length segments)]]
    (def {:value code-str} (get segments i))
    (when (peg/match pegs/comment-block-maybe code-str)
      (array/push comment-blocks code-str)))
  comment-blocks)
