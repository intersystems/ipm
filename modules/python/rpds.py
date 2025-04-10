r"""Note: 
This is a pure python implementation of the rpds-py library implemented using Rust here https://github.com/crate-py/rpds
This should be placed somewhere under <iris-root>/lib/python, so that when users decide to install the real rpds-py library, it will override this one.
"""

from collections.abc import Mapping, Iterable, Iterator, Set
from typing import Any, Generic, TypeVar

_T = TypeVar("_T")
_KT_co = TypeVar("_KT_co", covariant=True)
_VT_co = TypeVar("_VT_co", covariant=True)
_KU_co = TypeVar("_KU_co", covariant=True)
_VU_co = TypeVar("_VU_co", covariant=True)


class ItemsView(Generic[_KT_co, _VT_co]):
    def __init__(self, data: dict[_KT_co, _VT_co]) -> None:
        self._data = data

    def __iter__(self) -> Iterator[tuple[_KT_co, _VT_co]]:
        return iter(self._data.items())

    def __len__(self) -> int:
        return len(self._data)

    def __repr__(self) -> str:
        return f"ItemsView({list(self._data.items())})"


class KeysView(Generic[_KT_co]):
    def __init__(self, data: dict[_KT_co, Any]) -> None:
        self._data = data

    def __iter__(self) -> Iterator[_KT_co]:
        return iter(self._data.keys())

    def __len__(self) -> int:
        return len(self._data)

    def __contains__(self, key: object) -> bool:
        return key in self._data

    def __repr__(self) -> str:
        return f"KeysView({list(self._data.keys())})"

    # Some extra set‐operations mimicking the Rust keys view:
    def intersection(self, other: Iterable[_KT_co]) -> "HashTrieSet":
        return HashTrieSet(k for k in other if k in self._data)

    def union(self, other: Iterable[_KT_co]) -> "KeysView":
        new_data = dict(self._data)
        for k in other:
            new_data[k] = None
        return KeysView(new_data)


class ValuesView(Generic[_VT_co]):
    def __init__(self, data: dict[Any, _VT_co]) -> None:
        self._data = data

    def __iter__(self) -> Iterator[_VT_co]:
        return iter(self._data.values())

    def __len__(self) -> int:
        return len(self._data)

    def __repr__(self) -> str:
        return f"ValuesView({list(self._data.values())})"


class HashTrieMap(Mapping[_KT_co, _VT_co]):
    def __init__(
        self,
        value: Mapping[_KT_co, _VT_co] | Iterable[tuple[_KT_co, _VT_co]] = {},
        **kwds: _VT_co,
    ) -> None:
        # Accept either a mapping or an iterable of key/value pairs.
        if isinstance(value, Mapping):
            data = dict(value)
        else:
            data = {}
            for k, v in value:
                data[k] = v
        data.update(kwds)
        self._data: dict[_KT_co, _VT_co] = data

    def __getitem__(self, key: _KT_co) -> _VT_co:
        return self._data[key]

    def __iter__(self) -> Iterator[_KT_co]:
        return iter(self._data)

    def __len__(self) -> int:
        return len(self._data)

    def __contains__(self, key: object) -> bool:
        return key in self._data

    def __repr__(self) -> str:
        return f"HashTrieMap({self._data})"

    def __eq__(self, other: object) -> bool:
        if isinstance(other, Mapping):
            return dict(self._data) == dict(other)
        return NotImplemented

    def __hash__(self) -> int:
        # Hash as the hash of a frozenset of key-value pairs.
        try:
            return hash(frozenset(self._data.items()))
        except TypeError as e:
            raise TypeError("One or more keys/values are not hashable") from e

    def __reduce__(self):
        # For pickling: return a callable and its arguments.
        return (type(self), (self._data,))

    def get(self, key: _KT_co, default: Any = None) -> Any:
        return self._data.get(key, default)

    def discard(self, key: _KT_co) -> "HashTrieMap[_KT_co, _VT_co]":
        if key in self._data:
            new_data = dict(self._data)
            del new_data[key]
            return HashTrieMap(new_data)
        return self

    def remove(self, key: _KT_co) -> "HashTrieMap[_KT_co, _VT_co]":
        if key not in self._data:
            raise KeyError(key)
        new_data = dict(self._data)
        del new_data[key]
        return HashTrieMap(new_data)

    def insert(self, key: _KT_co, val: _VT_co) -> "HashTrieMap[_KT_co, _VT_co]":
        new_data = dict(self._data)
        new_data[key] = val
        return HashTrieMap(new_data)

    def update(
        self, *args: Mapping[_KU_co, _VU_co] | Iterable[tuple[_KU_co, _VU_co]]
    ) -> "HashTrieMap[_KT_co | _KU_co, _VT_co | _VU_co]":
        new_data = dict(self._data)
        for arg in args:
            if isinstance(arg, Mapping):
                new_data.update(arg)
            else:
                for k, v in arg:
                    new_data[k] = v
        return HashTrieMap(new_data)

    @classmethod
    def convert(
        cls, value: Mapping[_KT_co, _VT_co] | Iterable[tuple[_KT_co, _VT_co]]
    ) -> "HashTrieMap[_KT_co, _VT_co]":
        if isinstance(value, HashTrieMap):
            return value
        return cls(value)

    @classmethod
    def fromkeys(
        cls, keys: Iterable[_KT_co], value: _VT_co = None
    ) -> "HashTrieMap[_KT_co, _VT_co]":
        return cls({k: value for k in keys})


class HashTrieSet(frozenset, Generic[_T]):
    def __new__(cls, value: Iterable[_T] = ()) -> "HashTrieSet[_T]":
        # Use frozenset’s construction.
        return super().__new__(cls, value)

    def __init__(self, value: Iterable[_T] = ()):
        # Nothing to do; frozenset is already immutable.
        pass

    def __repr__(self) -> str:
        return f"HashTrieSet({set(self)})"

    def discard(self, value: _T) -> "HashTrieSet[_T]":
        if value in self:
            return HashTrieSet(self - {value})
        return self

    def remove(self, value: _T) -> "HashTrieSet[_T]":
        if value not in self:
            raise KeyError(value)
        return HashTrieSet(self - {value})

    def insert(self, value: _T) -> "HashTrieSet[_T]":
        return HashTrieSet(self | {value})

    def update(self, *args: Iterable[_T]) -> "HashTrieSet[_T]":
        new_set = set(self)
        for arg in args:
            new_set.update(arg)
        return HashTrieSet(new_set)

    # Set operations that return a HashTrieSet rather than a frozenset.
    def __and__(self, other: Iterable[_T]) -> "HashTrieSet[_T]":
        return HashTrieSet(super().__and__(set(other)))

    def __or__(self, other: Iterable[_T]) -> "HashTrieSet[_T]":
        return HashTrieSet(super().__or__(set(other)))

    def __sub__(self, other: Iterable[_T]) -> "HashTrieSet[_T]":
        return HashTrieSet(super().__sub__(set(other)))

    def __xor__(self, other: Iterable[_T]) -> "HashTrieSet[_T]":
        return HashTrieSet(super().__xor__(set(other)))

    def __reduce__(self):
        return (type(self), (list(self),))


class List(Iterable[_T], Generic[_T]):
    def __init__(self, value: Iterable[_T] = (), *more: _T) -> None:
        # If value is already a List, re-use its underlying tuple.
        if isinstance(value, List):
            self._data = value._data
        else:
            # If additional elements are given, append them at the end.
            if more:
                self._data = tuple(value) + more
            else:
                self._data = tuple(value)

    def __iter__(self) -> Iterator[_T]:
        return iter(self._data)

    def __len__(self) -> int:
        return len(self._data)

    def push_front(self, value: _T) -> "List[_T]":
        return List((value,) + self._data)

    def drop_first(self) -> "List[_T]":
        if not self._data:
            raise IndexError("drop_first on empty List")
        return List(self._data[1:])

    @property
    def first(self) -> _T:
        if not self._data:
            raise IndexError("empty list has no first element")
        return self._data[0]

    @property
    def rest(self) -> "List[_T]":
        if not self._data:
            raise IndexError("empty list has no rest elements")
        return List(self._data[1:])

    def __reversed__(self) -> "List[_T]":
        return List(reversed(self._data))

    def __hash__(self) -> int:
        return hash(self._data)

    def __eq__(self, other: object) -> bool:
        if isinstance(other, List):
            return self._data == other._data
        if isinstance(other, Iterable):
            return self._data == tuple(other)
        return NotImplemented

    def __ne__(self, other: object) -> bool:
        eq = self.__eq__(other)
        if eq is NotImplemented:
            return NotImplemented
        return not eq

    def __reduce__(self):
        return (type(self), (list(self),))

    def __repr__(self) -> str:
        return f"List({list(self._data)})"


class Queue(Iterable[_T], Generic[_T]):
    def __init__(self, value: Iterable[_T] = (), *more: _T) -> None:
        # If value is already a Queue, re-use its underlying tuple.
        if isinstance(value, Queue):
            self._data = value._data
        else:
            if more:
                self._data = tuple(value) + more
            else:
                self._data = tuple(value)

    def __iter__(self) -> Iterator[_T]:
        return iter(self._data)

    def __len__(self) -> int:
        return len(self._data)

    def enqueue(self, value: _T) -> "Queue[_T]":
        return Queue(self._data + (value,))

    def dequeue(self) -> "Queue[_T]":
        if not self._data:
            raise IndexError("dequeue from empty Queue")
        return Queue(self._data[1:])

    @property
    def is_empty(self) -> bool:
        return len(self._data) == 0

    @property
    def peek(self) -> _T:
        if not self._data:
            raise IndexError("peek from empty Queue")
        return self._data[0]

    def __hash__(self) -> int:
        return hash(self._data)

    def __eq__(self, other: object) -> bool:
        if isinstance(other, Queue):
            return self._data == other._data
        if isinstance(other, Iterable):
            return self._data == tuple(other)
        return NotImplemented

    def __reduce__(self):
        return (type(self), (list(self),))

    def __repr__(self) -> str:
        return f"Queue({list(self._data)})"
