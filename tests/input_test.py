import exrex
import io
import pytest
import random
from pytest import mark as pytestr
from flitsr.input import construct_details, construct_tests, fill_table
from flitsr.spectrum import Spectrum

def gen_strings(regex, num):
    ret = set()
    i = 0
    while(i < num):
        entry = exrex.getone(regex)
        if (entry not in ret):
            ret.add(entry)
            i += 1
    return list(ret)

@pytestr.randomize(entries=pytest.list_of(str, min_items=1, max_items=100),
        choices=gen_strings("([a-z.]+)\$([a-z]+)#([a-z(),]+):[0-9]+(:[0-9]+)?",
                            1000), ncalls=20)
def test_detail_construction(entries):
    entries = set(entries)
    num_entries = len(entries)
    entries = 'name\n' + '\n'.join(entries)
    spectrum = Spectrum()
    method_map = construct_details(io.StringIO(entries), False, spectrum)
    assert num_entries == len(spectrum.elements)

@pytestr.randomize(entries=pytest.list_of(str, min_items=1, max_items=100),
        choices=gen_strings("([a-z.]+),(PASS|FAIL)", 1000), ncalls=20)
def test_test_construction(entries):
    entries = set(entries)
    num_entries = len(entries)
    entries = 'name,outcome,runtime,stacktrace\n' + '\n'.join(entries)
    spectrum = Spectrum()
    method_map = construct_tests(io.StringIO(entries), spectrum)
    assert num_entries == len(spectrum.tests)

@pytestr.randomize(num_tests=int, num_elems=int, ncalls=10, max_num=500,
                   min_num=1)
def test_fill_table(num_tests, num_elems):
    # Constructing spectrum
    spectrum = Spectrum()
    # Filling elements
    method_map = {}
    elem_names = gen_strings("[a-z.]+", num_elems)
    elem_faults = [[random.randint(0, 100) for _ in range(random.randint(0, 3)%3)]
                                           for _ in range(num_elems)]
    for i in range(num_elems):
        elem = spectrum.addElement([elem_names[i]], elem_faults[i])
        method_map[i] = elem
    # Filling tests
    test_names = gen_strings("[a-z.]+", num_tests)
    test_outcomes = [bool(random.randint(0, 1)) for _ in range(num_tests)]
    for i in range(num_tests):
        spectrum.addTest(test_names[i], test_outcomes[i])
    matrix = ""
    elem_list = [i for i in range(num_elems)]
    for t in range(num_tests):
        execs = random.sample(elem_list, random.randint(0, num_elems))
        for e in elem_list:
            if (e in execs):
                matrix += "1 "
            else:
                matrix += "0 "
        matrix += str(test_outcomes[t])+"\n"
    fill_table(io.StringIO(matrix), method_map, spectrum)
    assert len(spectrum.failing) == len([t for t in test_outcomes if t == 0])
    assert spectrum.tf == len([t for t in test_outcomes if t == 0])
    assert spectrum.tp == len([t for t in test_outcomes if t == 1])
